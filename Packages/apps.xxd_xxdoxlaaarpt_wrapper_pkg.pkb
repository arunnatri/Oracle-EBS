--
-- XXD_XXDOXLAAARPT_WRAPPER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_XXDOXLAAARPT_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package   : APPS.XXD_XXDOXLAAARPT_WRAPPER_PKG
    * Author   : BT Technology Team
    * Created   : 25-NOV-2014
    * Program Name  : Account Analysis Report - Deckers
    * Description  : Wrapper Program to call the Account Analysis Report for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date   Developer    Version  Description
    *-----------------------------------------------------------------------------------------------
    *  25-Nov-2014 BT Technology Team  V1.1   Development
    *  21-Nov-2022 Ramesh Reddy        V1.2   Added for CCR0010275
    ************************************************************************************************/

    PROCEDURE submit_request_layout (errbuf OUT VARCHAR2, retcode OUT NUMBER, P_RESP_APPLICATION_ID IN NUMBER, P_LEDGER_ID IN VARCHAR2, P_LEDGER IN VARCHAR2, P_COA_ID IN NUMBER, P_LEGAL_ENTITY_ID IN NUMBER, P_LEGAL_ENTITY IN VARCHAR2, P_PERIOD_FROM IN VARCHAR2, P_PERIOD_TO IN VARCHAR2, P_GL_DATE_FROM IN VARCHAR2, P_GL_DATE_TO IN VARCHAR2, P_APPLICATION_ID IN NUMBER, P_JE_SOURCE_NAME IN VARCHAR2, P_JE_CATEGORY_NAME IN VARCHAR2, P_FROM_DATE IN VARCHAR2, P_TO_DATE IN VARCHAR2, P_CDATE IN VARCHAR2, P_BALANCE_TYPE_CODE IN VARCHAR2, P_BALANCE_TYPE IN VARCHAR2, P_DUMMY_BUDGET_VERSION IN VARCHAR2, P_BUDGET_VERSION_ID IN NUMBER, P_BUDGET_NAME IN VARCHAR2, P_DUMMY_ENCUMBRANCE_TYPE IN VARCHAR2, P_ENCUMBRANCE_TYPE_ID IN NUMBER, P_ENCUMBRANCE_TYPE IN VARCHAR2, P_BALANCE_SIDE_CODE IN VARCHAR2, P_BALANCE_SIDE IN VARCHAR2, P_BALANCE_AMOUNT_FROM IN NUMBER, P_BALANCE_AMOUNT_TO IN NUMBER, P_BALANCING_SEGMENT_FROM IN VARCHAR2, P_BALANCING_SEGMENT_TO IN VARCHAR2, P_ACCOUNT_SEGMENT_FROM IN VARCHAR2, P_ACCOUNT_SEGMENT_TO IN VARCHAR2, P_ACCOUNT_FLEXFIELD_FROM IN VARCHAR2, P_ACCOUNT_FLEXFIELD_TO IN VARCHAR2, P_INCLUDE_ZERO_AMOUNT_LINES IN VARCHAR2, P_INCLUDE_ZERO_AMT_LINES IN VARCHAR2, P_INCLUDE_USER_TRX_ID_FLAG IN VARCHAR2, P_INCLUDE_USER_TRX_ID IN VARCHAR2, P_INCLUDE_TAX_DETAILS_FLAG IN VARCHAR2, P_INCLUDE_TAX_DETAILS IN VARCHAR2, P_INCLUDE_LE_INFO_FLAG IN VARCHAR2, P_INCLUDE_LEGAL_ENTITY IN VARCHAR2, P_CUSTOM_PARAMETER_1 IN VARCHAR2, P_CUSTOM_PARAMETER_2 IN VARCHAR2, P_CUSTOM_PARAMETER_3 IN VARCHAR2, P_CUSTOM_PARAMETER_4 IN VARCHAR2, P_CUSTOM_PARAMETER_5 IN VARCHAR2, P_DEBUG_FLAG IN VARCHAR2, P_INCLUDE_STAT_AMOUNT_LINES IN VARCHAR2, P_INCLUDE_STAT_AMT_LINES IN VARCHAR2, P_INCLUDE_ACCT_WITH_NO_ACT IN VARCHAR2, P_INC_ACCT_WITH_NO_ACT IN VARCHAR2, P_SCALABLE_FLAG IN VARCHAR2, P_LONG_REPORT IN VARCHAR2, P_TBL_SELECT IN VARCHAR2 -- Added for CCR0010275
                                     , P_OUTPUT_TYPE IN VARCHAR2)
    AS
        ln_request_id   NUMBER;
        lc_boolean1     BOOLEAN;
        lc_boolean2     BOOLEAN;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'P_TBL_SELECT: ' || P_TBL_SELECT); --RRY

        fnd_file.put_line (fnd_file.LOG,
                           'In submit_request_layout Program....');

        --Set Layout
        IF P_OUTPUT_TYPE = 'EXCEL'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Adding Excel Layout.... ');

            lc_boolean1   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDXLAAARPT_EX',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'US', --Use territory from template definition
                    output_format        => 'EXCEL' --Use output format from template definition
                                                   );
        ELSIF P_OUTPUT_TYPE = 'TEXT'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');

            lc_boolean2   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDXLAAARPT_TX',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'US', --Use territory from template definition
                    output_format        => 'HTML' --Use output format from template definition
                                                  );
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Submitting Account Analysis Report - Deckers (Sub Program)..... ');

        ln_request_id   :=
            fnd_request.submit_request ('XXDO',                 -- application
                                                'XXDXLAAARPT', -- program short name
                                                               'Deckers Account Analysis Report', -- description
                                                                                                  SYSDATE, -- start time
                                                                                                           FALSE, -- sub request
                                                                                                                  P_RESP_APPLICATION_ID, P_LEDGER_ID, P_LEDGER, P_COA_ID, P_LEGAL_ENTITY_ID, P_LEGAL_ENTITY, P_PERIOD_FROM, P_PERIOD_TO, P_GL_DATE_FROM, P_GL_DATE_TO, P_APPLICATION_ID, P_JE_SOURCE_NAME, P_JE_CATEGORY_NAME, P_FROM_DATE, P_TO_DATE, P_CDATE, P_BALANCE_TYPE_CODE, P_BALANCE_TYPE, P_DUMMY_BUDGET_VERSION, P_BUDGET_VERSION_ID, P_BUDGET_NAME, P_DUMMY_ENCUMBRANCE_TYPE, P_ENCUMBRANCE_TYPE_ID, P_ENCUMBRANCE_TYPE, P_BALANCE_SIDE_CODE, P_BALANCE_SIDE, P_BALANCE_AMOUNT_FROM, P_BALANCE_AMOUNT_TO, P_BALANCING_SEGMENT_FROM, P_BALANCING_SEGMENT_TO, P_ACCOUNT_SEGMENT_FROM, P_ACCOUNT_SEGMENT_TO, P_ACCOUNT_FLEXFIELD_FROM, P_ACCOUNT_FLEXFIELD_TO, P_INCLUDE_ZERO_AMOUNT_LINES, P_INCLUDE_ZERO_AMT_LINES, P_INCLUDE_USER_TRX_ID_FLAG, P_INCLUDE_USER_TRX_ID, P_INCLUDE_TAX_DETAILS_FLAG, P_INCLUDE_TAX_DETAILS, P_INCLUDE_LE_INFO_FLAG, P_INCLUDE_LEGAL_ENTITY, P_CUSTOM_PARAMETER_1, P_CUSTOM_PARAMETER_2, P_CUSTOM_PARAMETER_3, P_CUSTOM_PARAMETER_4, P_CUSTOM_PARAMETER_5, P_DEBUG_FLAG, P_INCLUDE_STAT_AMOUNT_LINES, P_INCLUDE_STAT_AMT_LINES, P_INCLUDE_ACCT_WITH_NO_ACT, P_INC_ACCT_WITH_NO_ACT, P_SCALABLE_FLAG, P_LONG_REPORT, P_TBL_SELECT -- Added for CCR0010275
                                        , CHR (0) -- represents end of arguments
                                                 );


        IF ln_request_id = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Concurrent request failed to submit');
        ELSE
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Occured while running the Wrapper Program');
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR Details :' || SQLERRM || '-' || SQLCODE);
    END submit_request_layout;
END XXD_XXDOXLAAARPT_WRAPPER_PKG;
/
