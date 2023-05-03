--
-- XXDOAR021_CIT_TT  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoar021_cit_tt
AS
    FUNCTION before_report_1
        RETURN BOOLEAN
    IS
    BEGIN
        p_sql_stmt    :=
            'SELECT
            apps.fnd_profile.VALUE(''DO CIT: CLIENT NUMBER'')  CLIENT_NUMBER
        ,   :P_IDEN_REC             IDENTIFICATION_RECORD
        ,   RPAD('' '',1,'' '') TRADE_STYLE
        ,   CUST.CUST_ACCOUNT_ID
        ,   RPAD(CUST.ACCOUNT_NUMBER,15,'' '')  ACCOUNT_NUMBER
        ,   RPAD(TRX.TRX_NUMBER,8,'' '')        TRX_NUMBER
        ,   RPAD('' '',7,'' '') FILLER
        ,   TRX.BILL_TO_SITE_USE_ID
        ,   TRX.SHIP_TO_SITE_USE_ID
        ,   TRX_LINES.LINE_NUMBER
        ,   TRX_LINES.QUANTITY_INVOICED
        ,   TRX_LINES.UNIT_SELLING_PRICE*100	UNIT_SELLING_PRICE
        ,   TO_NUMBER(TO_CHAR(XSTG.AMOUNT_DUE_REMAINING,''99999999V99'')) AMOUNT_APPLIED
        ,   nvl(TRX_LINES.UOM_CODE,''EA'') MEASUREMENT_CODE
        ,   nvl(TRX_LINES.UOM_CODE,''PE'') UNIT_PRICE_CODE
        ,   RPAD(XCIV.ITEM_NUMBER,30,'' '') ITEM
        ,   CASE WHEN NVL(TRX_LINES.unit_selling_price,TRX_LINES.extended_amount) <0 THEN
            TRX_LINES.DESCRIPTION
            ELSE
            (RPAD(XCIV.item_description,30,'' '') ) END DESCRIPTION
        ,   RPAD(XCIV.STYLE_NUMBER,30,'' '') VENDOR_STYLE_NUMBER
        ,   TRX.TRX_DATE
        ,   lpad(decode(ps.DUE_DATE, NULL, 0, ps.DUE_DATE - ps.TRX_DATE ),3,0) CLIENT_TERMS_CODE
        ,   RPAD(RT.NAME,30,'' '')  TERMS_DESC
        ,   RPAD(TRX.PURCHASE_ORDER,22,'' '') PURCHASE_ORDER
        ,   TRX.PURCHASE_ORDER_DATE
        ,   XSTG.AMOUNT_LINE_ITEMS_REMAINING*100    AMOUNT_LINE_ITEMS_REMAINING
        ,   XSTG.TAX_REMAINING*100  TAX_REMAINING
        ,   XSTG.FREIGHT_REMAINING*100  FREIGHT_REMAINING
        ,   XSTG.RECEIVABLES_CHARGES_REMAINING*100  RECEIVABLES_CHARGES_REMAINING
        ,   RPAD(PARTY.PARTY_NAME,30,'' '')            CUST_BILL_TO_NAME
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''ADDR1'')     BILL_TO_ADDRESS_1
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''ADDR2'')     BILL_TO_ADDRESS_2
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''CITY'')      BILL_TO_CITY
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''STATE'')     BILL_TO_STATE
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''ZIP'')       BILL_TO_ZIP
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''COUNTRY'')   BILL_TO_COUNTRY
        ,   RPAD(XXDOOM_CIT_INT_PKG.Cust_Phone_f(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID),15,'' '')            CUSTOMER_PHONE
        ,   XXDOAR021_REP_PKG.cust_contact_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''FAX'')                CUSTOMER_FAX
        ,   RPAD(PARTY.DUNS_NUMBER_C,9,'' '')                                                                            CUSTOMER_DUNS
        ,   XXDOAR021_REP_PKG.cust_contact_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''EMAIL'')              CUSTOMER_EMAIL
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''ADDR1'')     SHIP_TO_ADDRESS_1
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''ADDR2'')     SHIP_TO_ADDRESS_2
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''CITY'')      SHIP_TO_CITY
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''STATE'')     SHIP_TO_STATE
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''ZIP'')       SHIP_TO_ZIP
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''COUNTRY'')   SHIP_TO_COUNTRY
        ,   XXDOAR021_REP_PKG.itm_color_style_desc(XCIV.INVENTORY_ITEM_ID,OSP.MASTER_ORGANIZATION_ID,''COLOR'')      COLOR_DESC
        ,   RPAD(SHIP_VIA.DESCRIPTION,30,'' '')        FREIGHT_CARRIER
        ,   RPAD(XCIV.UPC_CODE,20,'' '')             UPC_NUMBER
        ,   RPAD('' '',2,'' '')     SHIPMENT_PAY_CODE
        ,   LPAD(0,6,''0'')         NO_OF_CARTONS
            from
              APPS.XXD_CIT_DATA_STG_T                XSTG
            , APPS.AR_PAYMENT_SCHEDULES_ALL          PS
            , APPS.RA_CUSTOMER_TRX_ALL               TRX
            , APPS.RA_CUSTOMER_TRX_LINES_ALL         TRX_LINES
            , APPS.HZ_CUST_ACCOUNTS                  CUST
            , APPS.HZ_PARTIES                        PARTY
            , XXD_COMMON_ITEMS_V                     XCIV
            , APPS.RA_TERMS                          RT
            , APPS.OE_SYSTEM_PARAMETERS_ALL          OSP
            , (SELECT F.DESCRIPTION,FREIGHT_CODE
               FROM   APPS.ORG_FREIGHT F,
                      APPS.OE_SYSTEM_PARAMETERS_ALL OSP
               WHERE  F.ORGANIZATION_ID = OSP.MASTER_ORGANIZATION_ID
               AND    OSP.ORG_ID = :PN_ORG_ID)        SHIP_VIA
            Where
            XSTG.PAYMENT_SCHEDULE_ID            =   PS.PAYMENT_SCHEDULE_ID
            AND TRX.CUSTOMER_TRX_ID             =   XSTG.CUSTOMER_TRX_ID
            AND TRX.CUSTOMER_TRX_ID             =   TRX_LINES.CUSTOMER_TRX_ID
            and TRX_LINES.LINE_TYPE             =   ''LINE''
            and TRX.BILL_TO_CUSTOMER_ID         =   CUST.CUST_ACCOUNT_ID
            and CUST.PARTY_ID                   =   PARTY.PARTY_ID
            AND TRX_LINES.INVENTORY_ITEM_ID     =   XCIV.INVENTORY_ITEM_ID
            and XCIV.ORGANIZATION_ID             =   OSP.MASTER_ORGANIZATION_ID
            AND TRX.TERM_ID                     =   RT.TERM_ID
            AND TRX.SHIP_VIA                    =   SHIP_VIA.FREIGHT_CODE(+)
            AND XSTG.STATUS = ''DBC''
             AND XSTG.BATCH_ID                   =   :P_BATCH_ID
             AND OSP.ORG_ID                      =   :PN_ORG_ID
            order by CUST_BILL_TO_NAME, TRX.TRX_NUMBER,TRX_LINES.LINE_NUMBER';
        apps.fnd_file.put_line (apps.fnd_file.LOG, p_sql_stmt);
        p_sql_stmt2   := 'SELECT BATCH_ID
         ,FILE_NAME
         ,FTP_STATUS
         ,CUST_COUNT
         ,INVOICE_COUNT
         ,TOT_INV_AMT*100 TOT_INV_AMT
         ,BATCH_DATE
         ,NAME
         FROM XXD_CIT_CTL_STG_T
         WHERE BATCH_ID                   =   :P_BATCH_ID';
        apps.fnd_file.put_line (apps.fnd_file.LOG, p_sql_stmt2);
        COMMIT;
        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Before Report Failed');
            RETURN FALSE;
    END before_report_1;
END;
/
