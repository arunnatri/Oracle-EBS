--
-- XXD_XXDOAR005_CA_WRAPPER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_XXDOAR005_CA_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package         : APPS.XXD_XXDOAR005_CA_WRAPPER_PKG
    * Author         : Madhav Dhurjaty
    * Created         : 03-Nov-2016
    * Program Name  : Invoice Print - Selected - Deckers Canada
    * Description     : Wrapper Program to call the Invoice Print - Selected - Deckers Canada for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *-----------------------------------------------------------------------------------------------
    *     03-Nov-2016 Madhav Dhurjaty     V1.0         Development
    ************************************************************************************************/

    PROCEDURE submit_request_layout (errbuf OUT VARCHAR2, retcode OUT NUMBER, P_ORG_ID IN NUMBER, P_TRX_CLASS IN VARCHAR2, P_TRX_DATE_LOW IN VARCHAR2 --date
                                                                                                                                                     , P_TRX_DATE_HIGH IN VARCHAR2 --DATE
                                                                                                                                                                                  , P_CUSTOMER_ID IN NUMBER, P_CUST_BILL_TO IN NUMBER, P_INVOICE_NUM_FROM IN VARCHAR2, P_INVOICE_NUM_TO IN VARCHAR2, P_CUST_NUM_FROM IN VARCHAR2, P_CUST_NUM_TO IN VARCHAR2, P_BRAND IN VARCHAR2, P_ORDER_BY IN VARCHAR2, p_RE_TRANSMIT_FLAG IN VARCHAR2
                                     , P_FROM_EMAIL_ADDRESS IN VARCHAR2, p_send_email_flag IN VARCHAR2 -- Added for v1.3
                                                                                                      , p_cc_email_id IN VARCHAR2 -- Added for v1.4
                                                                                                                                 )
    AS
        ln_request_id   NUMBER;
        lc_boolean1     BOOLEAN;
        lc_boolean2     BOOLEAN;
        L_ORG_ID        NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'In submit_request_layout Program....');

        --Set Layout
        IF P_TRX_CLASS = 'DM'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Adding Excel Layout.... ');

            lc_boolean1   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR005_CA_DM',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'CA', --Use territory from template definition
                    output_format        => 'PDF' --Use output format from template definition
                                                 );
        ELSIF P_TRX_CLASS = 'CM'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');

            lc_boolean2   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR005_CA_CM',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'CA', --Use territory from template definition
                    output_format        => 'PDF' --Use output format from template definition
                                                 );
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');

            lc_boolean2   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR005_CA_INV',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'CA', --Use territory from template definition
                    output_format        => 'PDF' --Use output format from template definition
                                                 );
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Submitting Account Analysis Report - Deckers (Sub Program)..... ');

        ln_request_id   :=
            fnd_request.submit_request ('XXDO',                 -- application
                                                'XXDOAR005_CA', -- program short name
                                                                'Invoice Print - Selected - Deckers Canada', -- description
                                                                                                             SYSDATE, -- start time
                                                                                                                      FALSE -- sub request
                                                                                                                           , P_ORG_ID, P_TRX_CLASS, P_TRX_DATE_LOW, P_TRX_DATE_HIGH, P_CUSTOMER_ID, P_CUST_BILL_TO, P_INVOICE_NUM_FROM, P_INVOICE_NUM_TO, P_CUST_NUM_FROM, P_CUST_NUM_TO, P_BRAND, P_ORDER_BY, p_RE_TRANSMIT_FLAG, P_FROM_EMAIL_ADDRESS, p_send_email_flag -- Added for v1.3
                                                                                                                                                                                                                                                                                                                                                                          , p_cc_email_id -- Added for v1.4
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
/*start Added by BT Tech Team on 13-APR-2015*/
END XXD_XXDOAR005_CA_WRAPPER_PKG;
/
