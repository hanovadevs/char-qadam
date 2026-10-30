"""Calendar-based, immutable store redemption reports. No customer identity or QR secrets."""
import calendar
import hashlib
import io
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from pathlib import Path
from xml.sax.saxutils import escape
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, LongTable, TableStyle

PAKISTAN = ZoneInfo('Asia/Karachi')
MAX_LEDGER_ROWS = 10_000


def period_bounds(period: str, anchor: date) -> tuple[date, date]:
    if period == 'week':
        first = anchor - timedelta(days=anchor.weekday())
        return first, first + timedelta(days=6)
    if period == 'month':
        return anchor.replace(day=1), anchor.replace(day=calendar.monthrange(anchor.year, anchor.month)[1])
    raise ValueError('Choose week or month')


def utc_boundaries(first: date, last: date) -> tuple[datetime, datetime]:
    return (datetime.combine(first, time.min, PAKISTAN),
            datetime.combine(last + timedelta(days=1), time.min, PAKISTAN))


def ledger_path(report_id: str, settings) -> Path:
    import uuid
    try:
        report_id = str(uuid.UUID(report_id))
    except ValueError:
        raise HTTPException(404, 'Ledger not found') from None
    return Path(settings.media_directory).resolve() / 'merchant-ledgers' / f'{report_id}.pdf'


@dataclass(frozen=True)
class LedgerEntry:
    redeemed_at: datetime
    short_code: str
    title: str
    discount_type: str
    discount_value: Decimal
    store_id: str | None
    order_reference: str | None


def fixed_total(entries: list[LedgerEntry]) -> Decimal:
    return sum((row.discount_value for row in entries if row.discount_type == 'FIXED'), Decimal('0.00'))


def render_ledger(*, store_name: str, report_id: str, period: str, first: date, last: date,
                  generated_at: datetime, entries: list[LedgerEntry]) -> bytes:
    """Render wrapped, repeating table headers with explicit benefit units."""
    output = io.BytesIO()
    ink, teal, mint = colors.HexColor('#102B32'), colors.HexColor('#087F72'), colors.HexColor('#E8F6F2')
    normal = ParagraphStyle('body', fontName='Helvetica', fontSize=8, leading=11, textColor=ink)
    heading = ParagraphStyle('heading', parent=normal, fontName='Helvetica-Bold', fontSize=21, leading=27)
    small = ParagraphStyle('small', parent=normal, fontSize=7, leading=10)
    def text(value, style=normal):
        # Escape markup and discard control characters supplied in merchant references.
        cleaned = ''.join(c for c in str(value or '-') if c.isprintable() or c in '\n\t')
        return Paragraph(escape(cleaned).replace('\n', '<br/>'), style)
    title = f'Stepsy | {period.title()}ly redemption ledger' if period == 'week' else 'Stepsy | Monthly redemption ledger'
    story = [text(title, heading), text(store_name, ParagraphStyle('brand', parent=heading, fontSize=14, leading=20, textColor=teal)),
        Spacer(1, 8), text(f'{first:%d %b %Y} - {last:%d %b %Y} | Asia/Karachi'),
        text(f'Generated {generated_at.astimezone(PAKISTAN):%d %b %Y, %I:%M %p} PKT | Report {report_id}', small), Spacer(1, 12),
        text(f'{len(entries):,} redeemed vouchers | Fixed discounts: PKR {fixed_total(entries):,.2f}'),
        text('Percentage offers and free items are listed separately below. Fixed discounts are not total sales or total savings. Current periods contain activity recorded at generation time.', small), Spacer(1, 12)]
    data = [[text(label, ParagraphStyle('th', parent=normal, fontName='Helvetica-Bold', textColor=colors.white))
             for label in ['Redeemed (PKT)', 'Voucher', 'Reward', 'Benefit', 'Branch / terminal', 'Order reference']]]
    for entry in entries:
        benefit = ('Free item' if entry.discount_type == 'FREE_ITEM' else
                   f'{entry.discount_value.normalize():f}%' if entry.discount_type == 'PERCENT' else f'PKR {entry.discount_value:,.2f}')
        data.append([text(entry.redeemed_at.astimezone(PAKISTAN).strftime('%d %b %Y\n%I:%M %p')), text(entry.short_code),
                     text(entry.title), text(benefit), text(entry.store_id), text(entry.order_reference)])
    if entries:
        table = LongTable(data, colWidths=[92, 96, 198, 84, 115, 178], repeatRows=1, hAlign='LEFT')
        table.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), teal), ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, mint]),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'), ('LEFTPADDING', (0, 0), (-1, -1), 8), ('RIGHTPADDING', (0, 0), (-1, -1), 8),
            ('TOPPADDING', (0, 0), (-1, -1), 8), ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('LINEBELOW', (0, 0), (-1, 0), 0.5, teal)]))
        story.append(table)
    else:
        story.append(text('No vouchers were redeemed in this period.'))
    def footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(mint)
        canvas.line(38, 33, landscape(A4)[0] - 38, 33)
        canvas.setFont('Helvetica', 7)
        canvas.setFillColor(ink)
        canvas.drawString(38, 21, f'Stepsy | {store_name[:36]} | {first:%d %b %Y} - {last:%d %b %Y} | Report {report_id[:8]} | Private snapshot')
        canvas.drawRightString(landscape(A4)[0] - 38, 21, f'Page {doc.page}')
        canvas.restoreState()
    SimpleDocTemplate(output, pagesize=landscape(A4), leftMargin=38, rightMargin=38,
        topMargin=30, bottomMargin=45, title=title, author='Stepsy').build(story, onFirstPage=footer, onLaterPages=footer)
    return output.getvalue()


def save_ledger(data: bytes, report_id: str, settings) -> str:
    destination = ledger_path(report_id, settings)
    temporary = destination.with_suffix('.tmp')
    try:
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_bytes(data)
        temporary.replace(destination)
    except OSError:
        temporary.unlink(missing_ok=True)
        raise HTTPException(503, 'The ledger could not be stored. Please try again.') from None
    return hashlib.sha256(data).hexdigest()
