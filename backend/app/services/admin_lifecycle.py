"""History predicates shared by admin listings and guarded deletion."""
from sqlalchemy import or_, select
from app.db.models import ActivityDaily, LedgerReason, MerchantLedger, Offer, Partner, PointsLedger, Redemption, RedemptionRequest, User, Voucher


def offer_has_history(offer_id):
    return or_(
        select(Voucher.id).where(Voucher.offer_id == offer_id).exists(),
        select(RedemptionRequest.id).where(RedemptionRequest.offer_id == offer_id).exists(),
        select(PointsLedger.id).where(PointsLedger.ref_type == 'offer',
            PointsLedger.reason == LedgerReason.OFFER_SPEND, PointsLedger.ref_id == offer_id).exists(),
    )


def user_has_history(user_id):
    return or_(
        select(ActivityDaily.id).where(ActivityDaily.user_id == user_id).exists(),
        select(PointsLedger.id).where(PointsLedger.user_id == user_id).exists(),
        select(Voucher.id).where(Voucher.user_id == user_id).exists(),
        select(RedemptionRequest.id).where(RedemptionRequest.user_id == user_id).exists(),
    )


def partner_has_history(partner_id):
    offer_ids = select(Offer.id).where(Offer.partner_id == partner_id).correlate(Partner)
    member_ids = select(User.id).where(User.partner_id == partner_id).correlate(Partner)
    return or_(
        select(MerchantLedger.id).where(MerchantLedger.partner_id == partner_id).exists(),
        select(Voucher.id).where(Voucher.offer_id.in_(offer_ids)).exists(),
        select(RedemptionRequest.id).where(RedemptionRequest.offer_id.in_(offer_ids)).exists(),
        select(PointsLedger.id).where(PointsLedger.ref_type == 'offer',
            PointsLedger.reason == LedgerReason.OFFER_SPEND, PointsLedger.ref_id.in_(offer_ids)).exists(),
        select(Redemption.id).where(Redemption.partner_id == partner_id).exists(),
        select(ActivityDaily.id).where(ActivityDaily.user_id.in_(member_ids)).exists(),
        select(PointsLedger.id).where(PointsLedger.user_id.in_(member_ids)).exists(),
        select(Voucher.id).where(Voucher.user_id.in_(member_ids)).exists(),
        select(RedemptionRequest.id).where(RedemptionRequest.user_id.in_(member_ids)).exists(),
    )
