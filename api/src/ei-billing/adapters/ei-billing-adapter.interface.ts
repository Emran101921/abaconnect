import {
  EiBillingRecord,
  EiClearinghouseConfig,
  EiClearinghouseWorkflow,
} from '../../../generated/prisma/client';

export interface EiBillingExportResult {
  artifactType: 'EDI_837P' | 'CSV' | 'JSON';
  payload: string;
  fileName: string;
}

export interface EiBillingSubmitResult {
  accepted: boolean;
  externalReferenceId: string;
  message: string;
}

export interface EiBillingConnectionTestResult {
  success: boolean;
  message: string;
}

export interface IEiBillingAdapter {
  readonly workflow: EiClearinghouseWorkflow;
  export(
    record: EiBillingRecord,
    config: EiClearinghouseConfig,
  ): Promise<EiBillingExportResult>;
  submit(
    record: EiBillingRecord,
    config: EiClearinghouseConfig,
  ): Promise<EiBillingSubmitResult>;
  testConnection(
    config: EiClearinghouseConfig,
  ): Promise<EiBillingConnectionTestResult>;
}
