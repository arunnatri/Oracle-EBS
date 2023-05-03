--
-- XXD_XXDOAR005_US_WRAPPER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_XXDOAR005_US_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package         : APPS.XXD_XXDOAR005_US_WRAPPER_PKG
    * Author         : BT Technology Team
    * Created         : 25-NOV-2014
    * Program Name  : Account Analysis Report - Deckers
    * Description     : Wrapper Program to call the Account Analysis Report for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *-----------------------------------------------------------------------------------------------
    *     25-Nov-2014 BT Technology Team     V1.1         Development
    *     13-APR-2015 BT Technology Team     V1.2         Wrapper Program to call the Invoice Print - Selected - Deckers Shanghai for different output types
    *     11-JUL-2016 Infosys                V1.3      Wrapper Program to submit the bursting program based on send-email-flag parameter - INC0302174
    *     29-JUL-2016 Infosys                V1.4      To add cc email while sending outbound emails - ENHC0012628
    *     21-SEP-2016 Infosys                V1.5      Changes to control output file size for OPP - ENHC0012784
    ************************************************************************************************/

    PROCEDURE submit_request_layout (errbuf                    OUT VARCHAR2,
                                     retcode                   OUT NUMBER,
                                     P_ORG_ID               IN     NUMBER,
                                     P_TRX_CLASS            IN     VARCHAR2,
                                     P_TRX_DATE_LOW         IN     VARCHAR2 --date
                                                                           ,
                                     P_TRX_DATE_HIGH        IN     VARCHAR2 --DATE
                                                                           ,
                                     P_CUSTOMER_ID          IN     NUMBER,
                                     P_CUST_BILL_TO         IN     NUMBER,
                                     P_INVOICE_NUM_FROM     IN     VARCHAR2,
                                     P_INVOICE_NUM_TO       IN     VARCHAR2,
                                     P_CUST_NUM_FROM        IN     VARCHAR2,
                                     P_CUST_NUM_TO          IN     VARCHAR2,
                                     P_BRAND                IN     VARCHAR2,
                                     P_ORDER_BY             IN     VARCHAR2,
                                     p_RE_TRANSMIT_FLAG     IN     VARCHAR2,
                                     P_FROM_EMAIL_ADDRESS   IN     VARCHAR2,
                                     p_send_email_flag      IN     VARCHAR2 -- Added for v1.3
                                                                           ,
                                     p_cc_email_id          IN     VARCHAR2 -- Added for v1.4
                                                                           ,
                                     p_max_limit            IN     NUMBER,
                                     p_max_sets             IN     NUMBER)
    AS
        ln_request_id         NUMBER;
        lc_boolean1           BOOLEAN;
        lc_boolean2           BOOLEAN;
        L_ORG_ID              NUMBER;
        --  p_max_limit   NUMBER:=100;--- Added by Infosys for ENHC0012784
        --- p_max_sets    NUMBER:=5;--- Added by Infosys for ENHC0012784
        /*Added  below declarations by Infosys for ENHC0012784*/
        lc_phase              VARCHAR2 (50);
        lc_status             VARCHAR2 (50);
        lc_dev_phase          VARCHAR2 (50);
        lc_dev_status         VARCHAR2 (50);
        lc_message            VARCHAR2 (50);
        l_req_return_status   BOOLEAN;
    BEGIN
        SELECT ORGANIZATION_ID
          INTO L_ORG_ID
          FROM hr_operating_units
         WHERE NAME = 'Deckers Asia Pac Ltd OU';

        fnd_file.put_line (fnd_file.LOG,
                           'In submit_request_layout Program....');

        --Set Layout
        --Commented by Infosys for ENHC0012784 on 30-sep-2016
        /*IF P_ORG_ID = L_ORG_ID
        then
           IF P_TRX_CLASS = 'DM' THEN

          fnd_file.put_line(fnd_file.log,'Adding Excel Layout.... ');

          lc_boolean1 :=
                     fnd_request.add_layout (
                                  template_appl_name   => 'XXDO',
                                  template_code        => 'XXDOAR005_APAC_DM',
                                  template_language    => 'en', --Use language from template definition
                                  template_territory   => 'US', --Use territory from template definition
                                  output_format        => 'PDF' --Use output format from template definition
                                          );

          ELSIF P_TRX_CLASS = 'CM'  THEN

          fnd_file.put_line(fnd_file.log,'Adding Text Layout..... ');

          lc_boolean2 :=
                     fnd_request.add_layout (
                                  template_appl_name   => 'XXDO',
                                  template_code        => 'XXDOAR005_APAC_CM',
                                  template_language    => 'en', --Use language from template definition
                                  template_territory   => 'US', --Use territory from template definition
                                  output_format        => 'PDF' --Use output format from template definition
                                          );

                          ELSE

          fnd_file.put_line(fnd_file.log,'Adding Text Layout..... ');

          lc_boolean2 :=
                     fnd_request.add_layout (
                                  template_appl_name   => 'XXDO',
                                  template_code        => 'XXDOAR005_APAC_INV',
                                  template_language    => 'en', --Use language from template definition
                                  template_territory   => 'US', --Use territory from template definition
                                  output_format        => 'PDF' --Use output format from template definition
                                          );

          END IF;
          ELSE
         IF P_TRX_CLASS = 'DM' THEN

          fnd_file.put_line(fnd_file.log,'Adding Excel Layout.... ');

          lc_boolean1 :=
                     fnd_request.add_layout (
                                  template_appl_name   => 'XXDO',
                                  template_code        => 'XXDOAR005_US_DM',
                                  template_language    => 'en', --Use language from template definition
                                  template_territory   => 'US', --Use territory from template definition
                                  output_format        => 'PDF' --Use output format from template definition
                                          );

          ELSIF P_TRX_CLASS = 'CM'  THEN

          fnd_file.put_line(fnd_file.log,'Adding Text Layout..... ');

          lc_boolean2 :=
                     fnd_request.add_layout (
                                  template_appl_name   => 'XXDO',
                                  template_code        => 'XXDOAR005_US_CM',
                                  template_language    => 'en', --Use language from template definition
                                  template_territory   => 'US', --Use territory from template definition
                                  output_format        => 'PDF' --Use output format from template definition
                                          );

                          ELSE

          fnd_file.put_line(fnd_file.log,'Adding Text Layout..... ');

          lc_boolean2 :=
                     fnd_request.add_layout (
                                  template_appl_name   => 'XXDO',
                                  template_code        => 'XXDOAR005_US_INV',
                                  template_language    => 'en', --Use language from template definition
                                  template_territory   => 'US', --Use territory from template definition
                                  output_format        => 'PDF' --Use output format from template definition
                                          );

          END IF;
       END IF;*/
        --Commented by Infosys for ENHC0012784 on 30-sep-2016
        fnd_file.put_line (
            fnd_file.LOG,
            'Submitting Account Analysis Report - Deckers (Sub Program)..... ');

        ln_request_id   :=
            fnd_request.submit_request ('XXDO',                 -- application
                                                -- Modified by Infosys for ENHC0012784
                                                'XXD_INV_PRINT_SELECT_US', -- 'XXDOAR005_US',    -- program short name
                                                                           'Invoice Print - Selected - Deckers US', -- description
                                                                                                                    SYSDATE, -- start time
                                                                                                                             FALSE -- sub request
                                                                                                                                  , P_ORG_ID, P_TRX_CLASS, P_TRX_DATE_LOW, P_TRX_DATE_HIGH, P_CUSTOMER_ID, P_CUST_BILL_TO, P_INVOICE_NUM_FROM, P_INVOICE_NUM_TO, P_CUST_NUM_FROM, P_CUST_NUM_TO, P_BRAND, P_ORDER_BY, p_RE_TRANSMIT_FLAG, P_FROM_EMAIL_ADDRESS, p_send_email_flag -- Added for v1.3
                                                                                                                                                                                                                                                                                                                                                                                 , p_cc_email_id -- Added for v1.4
                                        , p_max_limit --- Added by Infosys for ENHC0012784
                                                     , p_max_sets --- Added by Infosys for ENHC0012784
                                                                 , CHR (0) -- represents end of arguments
                                                                          );


        IF ln_request_id = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Concurrent request failed to submit');
        ELSE
            COMMIT;
        END IF;

        ---Starts:Added Wait logic by Infosys on 30-sep-2016 for ENHC0012784
        IF ln_request_id > 0
        THEN
            LOOP
                l_req_return_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => ln_request_id,
                        INTERVAL     => 10,
                        max_wait     => 10000                     --in seconds
                                             -- out arguments
                                             ,
                        phase        => lc_phase,
                        STATUS       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;

            IF UPPER (lc_phase) = 'COMPLETED' AND UPPER (lc_status) = 'ERROR'
            THEN
                DBMS_OUTPUT.put_line (
                       'The Invoice Print - Selected - Deckers US completed in error. Oracle request id: '
                    || ln_request_id
                    || ' '
                    || SQLERRM);
            ELSIF     UPPER (lc_phase) = 'COMPLETED'
                  AND UPPER (lc_status) = 'NORMAL'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Concurrent program:Invoice Print - Selected - Deckers US Submitted Sucessfully-Request_id::'
                    || ln_request_id);
            END IF;
        END IF;
    ---Starts:Added Wait logic by Infosys on 30-sep-2016 for ENHC0012784

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
    PROCEDURE submit_request_layout_inv_chn (
        errbuf                    OUT VARCHAR2,
        retcode                   OUT NUMBER,
        P_ORG_ID               IN     NUMBER,
        P_TRX_CLASS            IN     VARCHAR2,
        P_TRX_DATE_LOW         IN     VARCHAR2                          --date
                                              ,
        P_TRX_DATE_HIGH        IN     VARCHAR2                          --DATE
                                              ,
        P_CUSTOMER_ID          IN     NUMBER,
        P_CUST_BILL_TO         IN     NUMBER,
        P_INVOICE_NUM_FROM     IN     VARCHAR2,
        P_INVOICE_NUM_TO       IN     VARCHAR2,
        P_CUST_NUM_FROM        IN     VARCHAR2,
        P_CUST_NUM_TO          IN     VARCHAR2,
        P_BRAND                IN     VARCHAR2,
        P_ORDER_BY             IN     VARCHAR2,
        p_RE_TRANSMIT_FLAG     IN     VARCHAR2,
        P_FROM_EMAIL_ADDRESS   IN     VARCHAR2)
    AS
        ln_request_id     NUMBER;
        lc_boolean1       BOOLEAN;
        lc_boolean2       BOOLEAN;
        lc_boolean3       BOOLEAN;
        lc_boolean4       BOOLEAN;

        lc_printer_name   VARCHAR2 (100);
        lc_style          VARCHAR2 (100);
        ln_copies         NUMBER;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'In submit_request_layout Program.... - ' || fnd_global.CONC_REQUEST_ID);

        BEGIN
            SELECT number_of_copies, printer, print_style
              INTO ln_copies, lc_printer_name, lc_style
              FROM fnd_concurrent_requests
             WHERE request_id = fnd_global.CONC_REQUEST_ID;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Error -  ' || SQLERRM);
                ln_copies         := NULL;
                lc_printer_name   := NULL;
                lc_style          := NULL;
        END;

        lc_boolean3   :=
            fnd_submit.set_print_options (printer   => lc_printer_name,
                                          style     => lc_style,
                                          copies    => ln_copies);

        lc_boolean4   :=
            fnd_request.add_printer (printer   => lc_printer_name,
                                     copies    => ln_copies);

        --Set Layout
        IF P_TRX_CLASS = 'DM'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Adding Excel Layout.... ');


            --IF lc_printer_name IS NOT NULL THEN

            --END IF;

            lc_boolean1   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR005_CN_DM',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'US', --Use territory from template definition
                    output_format        => 'PDF' --Use output format from template definition
                                                 );
        ELSIF P_TRX_CLASS = 'CM'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');

            lc_boolean2   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR005_CN_CM',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'US', --Use territory from template definition
                    output_format        => 'PDF' --Use output format from template definition
                                                 );
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');

            lc_boolean2   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR005_CN_INV',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'US', --Use territory from template definition
                    output_format        => 'PDF' --Use output format from template definition
                                                 );
        END IF;



        fnd_file.put_line (
            fnd_file.LOG,
            'Submitting Invoice Print - Selected - Deckers Shanghai (Sub Program)..... ');

        ln_request_id   :=
            fnd_request.submit_request ('XXDO',                 -- application
                                                'XXDOAR005_CN', -- program short name
                                                                'Invoice Print - Selected - Deckers Shanghai', -- description
                                                                                                               SYSDATE, -- start time
                                                                                                                        FALSE -- sub request
                                                                                                                             , P_ORG_ID, P_TRX_CLASS, P_TRX_DATE_LOW, P_TRX_DATE_HIGH, P_CUSTOMER_ID, P_CUST_BILL_TO, P_INVOICE_NUM_FROM, P_INVOICE_NUM_TO, P_CUST_NUM_FROM, P_CUST_NUM_TO, P_BRAND, P_ORDER_BY, p_RE_TRANSMIT_FLAG
                                        , P_FROM_EMAIL_ADDRESS, CHR (0) -- represents end of arguments
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
    END submit_request_layout_inv_chn;
/*End Added by BT Tech Team on 13-APR-2015*/
END XXD_XXDOAR005_US_WRAPPER_PKG;
/
