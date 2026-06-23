import { Injectable } from '@nestjs/common';
import {
  EiBillingRecord,
  EiClearinghouseConfig,
  EiClearinghouseWorkflow,
} from '../../../generated/prisma/client';
import {
  EiBillingConnectionTestResult,
  EiBillingExportResult,
  EiBillingSubmitResult,
  IEiBillingAdapter,
} from './ei-billing-adapter.interface';

abstract class BaseStubAdapter implements IEiBillingAdapter {
  abstract readonly workflow: EiClearinghouseWorkflow;
  protected abstract label: string;

  async export(
    record: EiBillingRecord,
    config: EiClearinghouseConfig,
  ): Promise<EiBillingExportResult> {
    return {
      artifactType: 'JSON',
      payload: JSON.stringify({
        stub: this.label,
        recordId: record.id,
        testMode: config.testMode,
      }),
      fileName: `${this.label.toLowerCase()}-${record.id.slice(0, 8)}.json`,
    };
  }

  async submit(
    record: EiBillingRecord,
    config: EiClearinghouseConfig,
  ): Promise<EiBillingSubmitResult> {
    return {
      accepted: true,
      externalReferenceId: `STUB-${this.label}-${record.id.slice(0, 8).toUpperCase()}`,
      message: `${this.label} stub accepted claim (testMode=${config.testMode})`,
    };
  }

  async testConnection(
    config: EiClearinghouseConfig,
  ): Promise<EiBillingConnectionTestResult> {
    if (!config.baaSignedAt) {
      return {
        success: false,
        message: 'BAA must be signed before connection test',
      };
    }
    return {
      success: true,
      message: `${this.label} stub connection OK`,
    };
  }
}

@Injectable()
export class StubEiHubAdapter extends BaseStubAdapter {
  readonly workflow = EiClearinghouseWorkflow.EI_HUB;
  protected label = 'EI-HUB';
}

@Injectable()
export class StubStateFiscalAgentAdapter extends BaseStubAdapter {
  readonly workflow = EiClearinghouseWorkflow.STATE_FISCAL_AGENT;
  protected label = 'STATE-FISCAL';
}

@Injectable()
export class StubEmednyAdapter extends BaseStubAdapter {
  readonly workflow = EiClearinghouseWorkflow.EMEDNY;
  protected label = 'EMEDNY';
}

@Injectable()
export class Edi837pExportAdapter implements IEiBillingAdapter {
  readonly workflow = EiClearinghouseWorkflow.EDI_837P_EXPORT;

  async export(
    record: EiBillingRecord,
    config: EiClearinghouseConfig,
  ): Promise<EiBillingExportResult> {
    const segments = [
      `ISA*00*          *00*          *ZZ*${config.submitterId ?? 'SUBMITTER'}*ZZ*${config.receiverId ?? 'RECEIVER'}*${new Date().toISOString().slice(0, 10).replace(/-/g, '')}*0000*^*00501*000000001*0*${config.testMode ? 'T' : 'P'}*:~`,
      `GS*HC*${config.submitterId ?? 'SUB'}*${config.receiverId ?? 'REC'}*${new Date().toISOString().slice(0, 10).replace(/-/g, '')}*0000*1*X*005010X222A1~`,
      `ST*837*0001*005010X222A1~`,
      `BHT*0019*00*${record.id.slice(0, 8)}*${new Date().toISOString().slice(0, 10).replace(/-/g, '')}*0000~`,
      `SE*4*0001~`,
      `GE*1*1~`,
      `IEA*1*000000001~`,
    ];
    return {
      artifactType: 'EDI_837P',
      payload: segments.join('\n'),
      fileName: `837p-${record.id.slice(0, 8)}.edi`,
    };
  }

  async submit(
    record: EiBillingRecord,
    config: EiClearinghouseConfig,
  ): Promise<EiBillingSubmitResult> {
    const exported = await this.export(record, config);
    return {
      accepted: true,
      externalReferenceId: `EDI837P-${record.id.slice(0, 8).toUpperCase()}`,
      message: `837P export generated (${exported.fileName}); manual upload required`,
    };
  }

  async testConnection(
    config: EiClearinghouseConfig,
  ): Promise<EiBillingConnectionTestResult> {
    if (!config.baaSignedAt) {
      return { success: false, message: 'BAA required for 837P export workflow' };
    }
    return { success: true, message: '837P export adapter ready (no live endpoint)' };
  }
}

@Injectable()
export class CsvExportAdapter implements IEiBillingAdapter {
  readonly workflow = EiClearinghouseWorkflow.CSV_EXPORT;

  async export(
    record: EiBillingRecord,
  ): Promise<EiBillingExportResult> {
    const header = 'record_id,service_date,units,status';
    const row = `${record.id},${record.serviceDate.toISOString().slice(0, 10)},${record.units},${record.queueStatus}`;
    return {
      artifactType: 'CSV',
      payload: `${header}\n${row}\n`,
      fileName: `ei-billing-${record.id.slice(0, 8)}.csv`,
    };
  }

  async submit(record: EiBillingRecord): Promise<EiBillingSubmitResult> {
    return {
      accepted: true,
      externalReferenceId: `CSV-${record.id.slice(0, 8).toUpperCase()}`,
      message: 'CSV export generated for manual clearinghouse upload',
    };
  }

  async testConnection(): Promise<EiBillingConnectionTestResult> {
    return { success: true, message: 'CSV export adapter ready' };
  }
}

@Injectable()
export class AuthorizedApiAdapter implements IEiBillingAdapter {
  readonly workflow = EiClearinghouseWorkflow.API_CLEARINGHOUSE;

  async export(
    record: EiBillingRecord,
    config: EiClearinghouseConfig,
  ): Promise<EiBillingExportResult> {
    this.assertAuthorized(config);
    return {
      artifactType: 'JSON',
      payload: JSON.stringify({
        recordId: record.id,
        endpointRef: config.apiEndpointRef ?? 'unset',
        testMode: config.testMode,
      }),
      fileName: `api-payload-${record.id.slice(0, 8)}.json`,
    };
  }

  async submit(
    record: EiBillingRecord,
    config: EiClearinghouseConfig,
  ): Promise<EiBillingSubmitResult> {
    this.assertAuthorized(config);
    if (!config.testMode) {
      return {
        accepted: false,
        externalReferenceId: '',
        message:
          'Live API clearinghouse disabled: configure test mode until BAA and enrollment are verified',
      };
    }
    return {
      accepted: true,
      externalReferenceId: `API-${record.id.slice(0, 8).toUpperCase()}`,
      message: 'Authorized API adapter stub submission (test mode)',
    };
  }

  async testConnection(
    config: EiClearinghouseConfig,
  ): Promise<EiBillingConnectionTestResult> {
    try {
      this.assertAuthorized(config);
      if (!config.apiEndpointRef?.trim()) {
        return {
          success: false,
          message: 'API endpoint reference not configured',
        };
      }
      return {
        success: true,
        message: 'Authorized API adapter configured (no live HTTP call)',
      };
    } catch (err) {
      return {
        success: false,
        message: err instanceof Error ? err.message : 'Unauthorized',
      };
    }
  }

  private assertAuthorized(config: EiClearinghouseConfig): void {
    if (!config.baaSignedAt) {
      throw new Error('Clearinghouse BAA must be signed');
    }
    if (!config.credentialsRef?.trim()) {
      throw new Error('Encrypted credentials reference required');
    }
  }
}
