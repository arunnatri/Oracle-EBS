--
-- XXD_XXDOAR037_WRAPPER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_XXDOAR037_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package      : APPS.XXD_XXDOAR037_WRAPPER_PKG
    * Author       : BT Technology Team
    * Created      : 20-NOV-2015
    * Program Name  : Transaction PDF File Generation Wrapper  Deckers
    * Description  : Wrapper Program to call the Transaction PDF File Generation  Deckers Report for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date     Developer                   Version  Description
    *-----------------------------------------------------------------------------------------------
    *  20-NOV-2015 BT Technology Team   V1.1     Development
    * 12-May-2016    Infosys            V2.0    Modified to implement parellel processing for invoices.
    * 01-Aug-2016   BT Technology Team      2.1      Changes for INC0305730 to add creation_date logic
    * 28-Jun-2017   Infosys             V3.0    Modified to include re-transmit logic for PRB0041178
    ************************************************************************************************/
    PROCEDURE submit_request_layout (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                                                                                                    p_creation_date_low IN VARCHAR2, p_creation_date_high IN VARCHAR2, --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                                                                                                                                                                       p_customer_id IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2
                                     , p_dir_loc IN VARCHAR2, p_batch_size IN NUMBER DEFAULT 300, -- Added by Infosys team. 12-May-2016.
                                                                                                  p_retransmit_flag IN VARCHAR2);
END xxd_xxdoar037_wrapper_pkg;
/
