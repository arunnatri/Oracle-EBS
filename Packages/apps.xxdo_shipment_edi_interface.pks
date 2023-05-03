--
-- XXDO_SHIPMENT_EDI_INTERFACE  (Package) 
--
--  Dependencies: 
--   FND_LOOKUP_VALUES (Synonym)
--   HZ_CUST_ACCOUNTS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_SHIPMENT_EDI_INTERFACE"
AS
    /******************************************************************************/
    /* Name       : Package XXDO_SHIPMENT_EDI_INTERFACE
    /* Created by : Infosys Ltd
    /* Created On : 2/28/2017
    /* Description: Package to build API to create Shipment EDI.
    /******************************************************************************/
    /**/
    g_lukbck_days   NUMBER := 30;
    g_log           CHAR (1) := 'N';

    CURSOR cur_edi_cust IS
        SELECT hca.account_number, hca.cust_account_id
          FROM apps.FND_LOOKUP_values flv, apps.hz_cust_accounts_all hca
         WHERE     1 = 1
               AND flv.lookup_type = 'XXDO_SOA_EDI_CUSTOMERS'
               AND flv.language = 'US'
               AND flv.ENABLED_FLAG = 'Y'
               AND flv.LOOKUP_CODE = hca.account_number;

    TYPE edi_cust_t IS TABLE OF cur_edi_cust%ROWTYPE;



    /******************************************************************************/
    /* Name         : CREATE_EDI
    /* Type          : PROCEDURE (Out : P_SHIPMENT_ID)
    /* Description  : PROCEDURE to Create EDI (API) called from other interface
    /******************************************************************************/
    PROCEDURE CREATE_EDI (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ORG_ID IN NUMBER, P_BOL_TRACK_NUMBER IN VARCHAR2, P_PRO_NUMBER IN VARCHAR2, P_LOAD_ID IN VARCHAR2
                          , P_SCAC IN VARCHAR2, P_SHIPMENT_ID OUT NUMBER);

    /******************************************************************************/
    /* Name         : RECREATE_EDI
    /* Type          : PROCEDURE
    /* Description  : PROCEDURE to delete EDI records to recreate it
    /******************************************************************************/

    PROCEDURE RECREATE_EDI (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ORG_ID IN NUMBER
                            , P_BOL_TRACK_NUMBER IN VARCHAR2);

    /******************************************************************************/
    /* Name         : CONC_MAIN_WRAP
    /* Type          : PROCEDURE
    /* Description  : PROCEDURE wrapper to build concurrent program and run in batch
    /******************************************************************************/
    PROCEDURE CONC_MAIN_WRAP (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_RUN_MODE IN VARCHAR2, P_RUN_TYPE IN VARCHAR2, P_ORG_ID IN NUMBER, P_BOL_TRACK_NUMBER IN VARCHAR2, P_PRO_NUMBER IN VARCHAR2, P_LOAD_ID IN VARCHAR2, P_SCAC IN VARCHAR2
                              , P_LUKBCK_DAYS IN NUMBER DEFAULT 30);
END XXDO_SHIPMENT_EDI_INTERFACE;
/
