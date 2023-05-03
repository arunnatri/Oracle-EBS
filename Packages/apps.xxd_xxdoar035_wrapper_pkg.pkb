--
-- XXD_XXDOAR035_WRAPPER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_XXDOAR035_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package      : APPS.XXD_XXDOAR035_WRAPPER_PKG
    * Author       : BT Technology Team
    * Created      : 27-JAN-2015
    * Program Name  : Print Transactions - Deckers
    * Description  : Wrapper Program to call the Print Transactions - Deckers Report for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date     Developer         Version  Description
    *-----------------------------------------------------------------------------------------------
    *  27-JAN-2015 BT Technology Team   V1.1     Development
    *  14-APR-2015 BT Technology Team   V1.2     Wrapper Program to call the Print Transactions - Deckers(CHN)
    *                                             Report for different output types
    *  11-AUG-2016 Infosys              V1.3      To add cc email while sending outbound emails - ENHC0012628
    *  18-OCT-2016  Infosys             V1.4      XXD_PRINT_TRX_DEC
    *  25-AUG-2017 Madhav D             V1.4      Added Creation date parameters
    ************************************************************************************************/
    PROCEDURE submit_request_layout (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_creation_date_low IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                            p_creation_date_high IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                                                              p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, p_customer_id IN NUMBER, p_cust_bill_to IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2, p_cust_num_to IN VARCHAR2, p_brand IN VARCHAR2, p_order_by IN VARCHAR2, p_re_transmit_flag IN VARCHAR2, -- p_from_email_address   IN       VARCHAR2,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_printer IN VARCHAR2, p_copies IN NUMBER, p_cc_email_id IN VARCHAR2, -- Added for v1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   p_max_limit IN NUMBER
                                     , p_max_sets IN NUMBER)
    AS
        ln_request_id   NUMBER;
        lc_boolean1     BOOLEAN;
        lc_boolean2     BOOLEAN;
        l_org_id        NUMBER;
    BEGIN
        /* START Commented as part of  v1.4
        SELECT organization_id INTO l_org_id FROM hr_operating_units WHERE NAME = 'Deckers Asia Pac Ltd OU';
           fnd_file.put_line (fnd_file.LOG,
                              'In submit_request_layout Program....');
        if p_org_id = l_org_id then
        IF p_trx_class = 'DM'
           THEN
              fnd_file.put_line (fnd_file.LOG, 'Adding Excel Layout.... ');
              lc_boolean1 :=
                 fnd_request.add_layout (template_appl_name      => 'XXDO',
                                         template_code           => 'XXDOAR035_APAC_DM',
                                         template_language       => 'en',
                                         --Use language from template definition
                                         template_territory      => 'US',
                                         --Use territory from template definition
                                         output_format           => 'PDF'
                                        --Use output format from template definition
                                        );
           ELSIF p_trx_class = 'CM'
           THEN
              fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');
              lc_boolean2 :=
                 fnd_request.add_layout (template_appl_name      => 'XXDO',
                                         template_code           => 'XXDOAR035_APAC_CM',
                                         template_language       => 'en',
                                         --Use language from template definition
                                         template_territory      => 'US',
                                         --Use territory from template definition
                                         output_format           => 'PDF'
                                        --Use output format from template definition
                                        );
           ELSE
              fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');
              lc_boolean2 :=
                 fnd_request.add_layout (template_appl_name      => 'XXDO',
                                         template_code           => 'XXDOAR035_APAC_INV',
                                         template_language       => 'en',
                                         --Use language from template definition
                                         template_territory      => 'US',
                                         --Use territory from template definition
                                         output_format           => 'PDF'
                                        --Use output format from template definition
                                        );
           END IF;
        else
           IF p_trx_class = 'DM'
           THEN
              fnd_file.put_line (fnd_file.LOG, 'Adding Excel Layout.... ');
              lc_boolean1 :=
                 fnd_request.add_layout (template_appl_name      => 'XXDO',
                                         template_code           => 'XXDOAR035_DM',
                                         template_language       => 'en',
                                         --Use language from template definition
                                         template_territory      => 'US',
                                         --Use territory from template definition
                                         output_format           => 'PDF'
                                        --Use output format from template definition
                                        );
           ELSIF p_trx_class = 'CM'
           THEN
              fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');
              lc_boolean2 :=
                 fnd_request.add_layout (template_appl_name      => 'XXDO',
                                         template_code           => 'XXDOAR035_CM',
                                         template_language       => 'en',
                                         --Use language from template definition
                                         template_territory      => 'US',
                                         --Use territory from template definition
                                         output_format           => 'PDF'
                                        --Use output format from template definition
                                        );
           ELSE
              fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');
              lc_boolean2 :=
                 fnd_request.add_layout (template_appl_name      => 'XXDO',
                                         template_code           => 'XXDOAR035_INV',
                                         template_language       => 'en',
                                         --Use language from template definition
                                         template_territory      => 'US',
                                         --Use territory from template definition
                                         output_format           => 'PDF'
                                        --Use output format from template definition
                                        );
           END IF;
           end if;*/
        --Commented by Infosys for v1.4

        fnd_file.put_line (
            fnd_file.LOG,
            'Submitting Print Transactions - Deckers (Sub Program)..... ');
        ln_request_id   :=
            fnd_request.submit_request ('XXDO',                 -- application
                                                'XXD_PRINT_TRX_DEC', -- program short name
                                                                     'Print Transactions - Deckers', -- description
                                                                                                     SYSDATE, -- start time
                                                                                                              FALSE -- sub request
                                                                                                                   , p_org_id, p_trx_class, p_creation_date_low, --Added for CCR0005936
                                                                                                                                                                 p_creation_date_high, --Added for CCR0005936
                                                                                                                                                                                       p_trx_date_low, p_trx_date_high, p_customer_id, p_cust_bill_to, p_invoice_num_from, p_invoice_num_to, p_cust_num_from, p_cust_num_to, p_brand, p_order_by, p_re_transmit_flag, -- p_from_email_address,
                                                                                                                                                                                                                                                                                                                                                                      p_printer, p_copies, p_cc_email_id, -- Added for v1.3
                                                                                                                                                                                                                                                                                                                                                                                                          p_max_limit
                                        ,                 --- Added by Infosys
                                          p_max_sets      --- Added by Infosys
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

    PROCEDURE submit_request_layout_pri_chn (
        errbuf                  OUT VARCHAR2,
        retcode                 OUT NUMBER,
        p_org_id             IN     NUMBER,
        p_trx_class          IN     VARCHAR2,
        p_trx_date_low       IN     VARCHAR2,
        p_trx_date_high      IN     VARCHAR2,
        p_customer_id        IN     NUMBER,
        p_cust_bill_to       IN     NUMBER,
        p_invoice_num_from   IN     VARCHAR2,
        p_invoice_num_to     IN     VARCHAR2,
        p_cust_num_from      IN     VARCHAR2,
        p_cust_num_to        IN     VARCHAR2,
        p_brand              IN     VARCHAR2,
        p_order_by           IN     VARCHAR2,
        p_re_transmit_flag   IN     VARCHAR2,
        -- p_from_email_address   IN       VARCHAR2,
        p_printer            IN     VARCHAR2,
        p_copies             IN     NUMBER)
    AS
        ln_request_id   NUMBER;
        lc_boolean1     BOOLEAN;
        lc_boolean2     BOOLEAN;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'In submit_request_layout Program....');

        --Set Layout
        IF p_trx_class = 'DM'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Adding Excel Layout.... ');
            lc_boolean1   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR035_CN_DM',
                    template_language    => 'en',
                    --Use language from template definition
                    template_territory   => 'US',
                    --Use territory from template definition
                    output_format        => 'PDF'--Use output format from template definition
                                                 );
        ELSIF p_trx_class = 'CM'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');
            lc_boolean2   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR035_CN_CM',
                    template_language    => 'en',
                    --Use language from template definition
                    template_territory   => 'US',
                    --Use territory from template definition
                    output_format        => 'PDF'--Use output format from template definition
                                                 );
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');
            lc_boolean2   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'XXDOAR035_CN_INV',
                    template_language    => 'en',
                    --Use language from template definition
                    template_territory   => 'US',
                    --Use territory from template definition
                    output_format        => 'PDF'--Use output format from template definition
                                                 );
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Submitting Print Transactions - Deckers(CHN) (Sub Program)..... ');
        ln_request_id   :=
            fnd_request.submit_request ('XXDO',                 -- application
                                                'XXDOAR035_CN', -- program short name
                                                                'Print Transactions - Deckers(CHN)', -- description
                                                                                                     SYSDATE, -- start time
                                                                                                              FALSE -- sub request
                                                                                                                   , p_org_id, p_trx_class, p_trx_date_low, p_trx_date_high, p_customer_id, p_cust_bill_to, p_invoice_num_from, p_invoice_num_to, p_cust_num_from, p_cust_num_to, p_brand, p_order_by, p_re_transmit_flag
                                        , -- p_from_email_address,
                                          p_printer, p_copies);

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
    END submit_request_layout_pri_chn;
END xxd_xxdoar035_wrapper_pkg;
/
