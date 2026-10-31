export function csvCell(value) {
  let text = String(value ?? '');
  // Prevent spreadsheet formula injection from names and administrator notes.
  if (/^[\s]*[=+\-@\t\r\n]/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}
export function downloadCsv(name, rows, columns) {
  const lines = [columns.map(c => csvCell(c.label)).join(','), ...rows.map(row => columns.map(c => csvCell(row[c.key])).join(','))];
  const url = URL.createObjectURL(new Blob(['\uFEFF' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url; link.download = name; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
