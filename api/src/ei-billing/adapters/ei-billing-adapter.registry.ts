import { BadRequestException, Injectable } from '@nestjs/common';
import { EiClearinghouseWorkflow } from '../../../generated/prisma/client';
import { IEiBillingAdapter } from './ei-billing-adapter.interface';
import {
  AuthorizedApiAdapter,
  CsvExportAdapter,
  Edi837pExportAdapter,
  StubEiHubAdapter,
  StubEmednyAdapter,
  StubStateFiscalAgentAdapter,
} from './ei-billing-adapters';

@Injectable()
export class EiBillingAdapterRegistry {
  private readonly adapters: Map<EiClearinghouseWorkflow, IEiBillingAdapter>;

  constructor(
    eiHub: StubEiHubAdapter,
    stateFiscal: StubStateFiscalAgentAdapter,
    emedny: StubEmednyAdapter,
    edi837p: Edi837pExportAdapter,
    csv: CsvExportAdapter,
    api: AuthorizedApiAdapter,
  ) {
    this.adapters = new Map<EiClearinghouseWorkflow, IEiBillingAdapter>([
      [EiClearinghouseWorkflow.EI_HUB, eiHub],
      [EiClearinghouseWorkflow.STATE_FISCAL_AGENT, stateFiscal],
      [EiClearinghouseWorkflow.EMEDNY, emedny],
      [EiClearinghouseWorkflow.EDI_837P_EXPORT, edi837p],
      [EiClearinghouseWorkflow.CSV_EXPORT, csv],
      [EiClearinghouseWorkflow.API_CLEARINGHOUSE, api],
    ]);
  }

  getAdapter(workflow: EiClearinghouseWorkflow): IEiBillingAdapter {
    const adapter = this.adapters.get(workflow);
    if (!adapter) {
      throw new BadRequestException(`No adapter registered for ${workflow}`);
    }
    return adapter;
  }
}
