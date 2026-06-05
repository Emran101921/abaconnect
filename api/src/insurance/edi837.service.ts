import { Injectable } from '@nestjs/common';

export interface Edi837ClaimInput {
  claimId: string;
  claimNumber?: string | null;
  payerName: string;
  billedAmount: number;
  serviceDate: Date;
  childFirstName: string;
  childLastName: string;
  diagnosisCodes: string[];
  cptCode: string;
  units: number;
  providerNpi?: string | null;
  memberId?: string | null;
}

@Injectable()
export class Edi837Service {
  build837Payload(input: Edi837ClaimInput): Record<string, unknown> {
    const serviceDate = input.serviceDate
      .toISOString()
      .slice(0, 10)
      .replace(/-/g, '');
    const claimNumber =
      input.claimNumber ?? `CLM-${input.claimId.slice(0, 8).toUpperCase()}`;

    return {
      format: '837P',
      version: '005010X222A1',
      interchangeControlNumber: claimNumber,
      claim: {
        claimId: input.claimId,
        claimNumber,
        payerName: input.payerName,
        billedAmount: input.billedAmount,
        serviceDate,
        patient: {
          firstName: input.childFirstName,
          lastName: input.childLastName,
          memberId: input.memberId ?? undefined,
        },
        diagnosis: input.diagnosisCodes,
        serviceLines: [
          {
            cpt: input.cptCode,
            units: input.units,
            chargeAmount: input.billedAmount,
          },
        ],
        renderingProvider: {
          npi: input.providerNpi ?? '0000000000',
        },
      },
      segments: this.buildStubSegments(input, claimNumber, serviceDate),
    };
  }

  private buildStubSegments(
    input: Edi837ClaimInput,
    claimNumber: string,
    serviceDate: string,
  ): string[] {
    return [
      `ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *${serviceDate}*0000*^*00501*${claimNumber}*0*P*:~`,
      `GS*HC*SENDER*RECEIVER*${serviceDate}*0000*1*X*005010X222A1~`,
      `ST*837*0001*005010X222A1~`,
      `BHT*0019*00*${claimNumber}*${serviceDate}*0000*CH~`,
      `NM1*IL*1*${input.childLastName}*${input.childFirstName}****MI*${input.memberId ?? 'UNKNOWN'}~`,
      `CLM*${claimNumber}*${input.billedAmount.toFixed(2)}***11:B:1*Y*A*Y*Y~`,
      `HI*ABK:${input.diagnosisCodes[0] ?? 'F84.0'}~`,
      `SV1*HC:${input.cptCode}*${input.billedAmount.toFixed(2)}*UN*${input.units}***1~`,
      `SE*8*0001~`,
      `GE*1*1~`,
      `IEA*1*${claimNumber}~`,
    ];
  }
}
