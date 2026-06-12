import PDFDocument from 'pdfkit';
import { ServiceLog } from '../../generated/prisma/client';

type ServiceLogPdfContext = {
  childName: string;
  therapistName: string;
  sessionDate?: string;
};

const line = (doc: PDFKit.PDFDocument, label: string, value: string) => {
  doc.font('Helvetica-Bold').text(`${label}: `, { continued: true });
  doc.font('Helvetica').text(value || '—');
};

export function buildServiceLogPdf(
  log: ServiceLog,
  context: ServiceLogPdfContext,
): Promise<Buffer> {
  const data = log.logData as Record<string, unknown>;

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50, size: 'LETTER' });
    const chunks: Buffer[] = [];
    doc.on('data', (chunk: Buffer) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc.fontSize(18).font('Helvetica-Bold').text('Service Log Sheet');
    doc.moveDown(0.5);
    doc
      .fontSize(10)
      .font('Helvetica')
      .fillColor('#444444')
      .text('Early intervention service documentation');
    doc.fillColor('#000000');
    doc.moveDown();

    doc.fontSize(12).font('Helvetica-Bold').text('Child information');
    doc.moveDown(0.3);
    line(doc, 'Name', String(data.childName ?? context.childName));
    line(doc, 'Date of birth', String(data.childDob ?? ''));
    line(doc, 'Sex', String(data.childSex ?? ''));
    doc.moveDown();

    doc.fontSize(12).font('Helvetica-Bold').text('Parent / caregiver');
    doc.moveDown(0.3);
    line(doc, 'Name', String(data.parentName ?? ''));
    line(doc, 'Email', String(data.parentEmail ?? ''));
    line(doc, 'Phone', String(data.parentPhone ?? ''));
    line(doc, 'Relationship to child', String(data.parentRelationship ?? ''));
    doc.moveDown();

    doc.fontSize(12).font('Helvetica-Bold').text('Session information');
    doc.moveDown(0.3);
    line(doc, 'Therapist / interventionist', context.therapistName);
    if (context.sessionDate) {
      line(doc, 'Session date', context.sessionDate);
    }
    line(doc, 'Service type', String(data.serviceType ?? ''));
    line(doc, 'IFSP service location', String(data.ifspServiceLocation ?? ''));
    line(
      doc,
      'Time',
      `${String(data.timeFrom ?? '')} – ${String(data.timeTo ?? '')}`,
    );
    line(doc, 'Session delivered', String(data.sessionDelivered ?? ''));
    doc.moveDown();

    if (log.therapistSignatureName) {
      doc.fontSize(12).font('Helvetica-Bold').text('Therapist signature');
      doc.moveDown(0.3);
      line(doc, 'Name', log.therapistSignatureName);
      if (log.therapistSignedAt) {
        line(
          doc,
          'Signed at',
          log.therapistSignedAt.toISOString().replace('T', ' ').slice(0, 19),
        );
      }
      doc.moveDown();
    }

    if (log.parentSignatureName) {
      doc
        .fontSize(12)
        .font('Helvetica-Bold')
        .text('Parent / caregiver signature');
      doc.moveDown(0.3);
      doc
        .fontSize(11)
        .font('Helvetica-Bold')
        .fillColor('#1b5e20')
        .text('Signed by parent');
      doc.fillColor('#000000');
      doc.moveDown(0.3);
      line(doc, 'Name', log.parentSignatureName);
      line(doc, 'Date', log.parentSignatureDate ?? '');
      if (log.parentSignatureLat != null && log.parentSignatureLng != null) {
        line(
          doc,
          'GPS verification',
          `${log.parentSignatureLat.toString()}, ${log.parentSignatureLng.toString()}`,
        );
      }
      if (log.parentSignedAt) {
        line(
          doc,
          'Recorded at',
          log.parentSignedAt.toISOString().replace('T', ' ').slice(0, 19),
        );
      }
      doc.moveDown();
    }

    doc.fontSize(12).font('Helvetica-Bold').text('Session summary');
    doc.moveDown(0.3);
    line(doc, 'IFSP outcomes (#1)', String(data.q1IfspOutcomes ?? ''));
    line(
      doc,
      'Session description (#2)',
      String(data.q2SessionDescription ?? ''),
    );
    line(doc, 'Home strategies (#4)', String(data.q4HomeStrategies ?? ''));

    doc.end();
  });
}
