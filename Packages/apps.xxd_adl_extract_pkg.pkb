--
-- XXD_ADL_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_ADL_EXTRACT_PKG
AS
    gc_module                       VARCHAR2 (100) := 'XXD_ADL_EXTRACT_PKG';
    gn_user_id                      NUMBER := fnd_global.user_id;
    gn_resp_id                      NUMBER := fnd_global.resp_id;
    gn_resp_appl_id                 NUMBER := fnd_global.resp_appl_id;
    gd_sysdate                      DATE := SYSDATE;
    gc_code_pointer                 VARCHAR2 (500);
    gc_default_aging_bucket         VARCHAR2 (10);
    gc_score_component1             VARCHAR2 (30) := 'AGING_WATERFALL';
    gc_risk_component1              VARCHAR2 (30) := 'LAST_PAYMENT';
    gc_risk_component2              VARCHAR2 (30) := 'BOOKED_ORDERS';
    gc_risk_component3              VARCHAR2 (30) := 'ADL_TREND';
    gc_exception_flag               VARCHAR2 (1) := 'N';
    gn_org_id                       NUMBER;
    gc_ao_days                      NUMBER; --Days between request date and order date in AT ONCE Order
    gn_gl_first_quarter             NUMBER := 1;
    gn_gl_Last_quarter              NUMBER := 4;
    gn_adl_rolling_days             NUMBER;
    gn_booked_order_default_score   NUMBER;                                 --
    gn_cust_account_id              NUMBER;
    gc_log_profile_value            VARCHAR2 (1);
    gc_all_brand_code               VARCHAR2 (20);
    gc_insert_check                 VARCHAR2 (1);
    gn_dist_low_cutoff_score        NUMBER := 100;
    gn_dist_high_cutoff_score       NUMBER := 50;
    gn_jpn_low_score                NUMBER := 100;
    gn_jpn_mod_score                NUMBER := 50;
    gn_jpn_hard1_score              NUMBER := 20;
    gn_jpn_hard2_score              NUMBER := 10;
    gc_deckers_bucket_name          VARCHAR2 (100)
        := FND_PROFILE.VALUE ('IEX_COLLECTIONS_BUCKET_NAME');
    gn_ecomm_score                  NUMBER := 50;
    lc_out_line                     VARCHAR2 (10000);


    PROCEDURE POPULATE_ADL (p_org_id           IN NUMBER,
                            p_cust_acct_id     IN NUMBER,
                            p_brand            IN VARCHAR2,
                            p_account_number      VARCHAR2,
                            p_org_name         IN VARCHAR2)
    IS
        ln_inv_count          NUMBER;
        l_run_date            DATE := TRUNC (SYSDATE);
        ld_first_pay_date     DATE;
        ln_adl                NUMBER;
        ln_ou                 NUMBER := P_ORG_ID;
        ln_c                  NUMBER := 0;
        ln_cust_account_id    NUMBER := p_cust_acct_id;

        CURSOR adl_quarters_c (p_quarter_start_date IN DATE)
        IS
              SELECT DISTINCT quarter_start_date, (ADD_MONTHS (TRUNC (quarter_start_date, 'q'), 3) - 1) quarter_end_date, period_year,
                              quarter_num, NULL adl, NULL invcount
                FROM gl_periods
               WHERE     quarter_start_date BETWEEN ADD_MONTHS (
                                                        TRUNC (
                                                            p_quarter_start_date,
                                                            'q'),
                                                        -27)
                                                AND ADD_MONTHS (
                                                          TRUNC (
                                                              p_quarter_start_date,
                                                              'q')
                                                        - 1,
                                                        -3)
                     AND period_set_name = 'Deckers Caldr'
            ORDER BY period_year ASC, quarter_num ASC;

        CURSOR inv_count_c (p_start_date IN DATE, p_end_date IN DATE, p_cust_acct_id IN NUMBER
                            , p_brand IN VARCHAR2)
        IS
            SELECT NVL (COUNT (*), 0)
              FROM ar_payment_schedules_all apsa, ra_customer_trx_all rct
             WHERE     1 = 1
                   AND rct.trx_date BETWEEN p_start_date AND p_end_date
                   -- AND apsa.actual_date_closed > apsa.due_date -- Commented as per CR#110
                   AND apsa.status = 'CL'
                   AND rct.bill_to_customer_id = p_cust_acct_id
                   AND rct.attribute5 = p_brand
                   AND rct.customer_trx_id = apsa.customer_trx_id
                   AND rct.org_id = p_org_id;

        CURSOR open_inv_count_c (p_start_date IN DATE, p_end_date IN DATE, p_cust_acct_id IN NUMBER
                                 , p_brand IN VARCHAR2)
        IS
            SELECT NVL (COUNT (*), 0)
              FROM ar_payment_schedules_all apsa, ra_customer_trx_all rct
             WHERE     1 = 1
                   AND rct.trx_date BETWEEN p_start_date AND p_end_date
                   --  AND apsa.actual_date_closed > apsa.due_date -- Commented as per CR#110
                   AND apsa.status = 'OP'
                   AND rct.bill_to_customer_id = p_cust_acct_id
                   AND rct.attribute5 = p_brand
                   AND rct.customer_trx_id = apsa.customer_trx_id
                   AND rct.org_id = p_org_id;


        CURSOR first_pay_date (p_cust_acc_id IN NUMBER, p_brand IN VARCHAR2)
        IS
            SELECT TRUNC (MIN (apsa.actual_date_closed), 'q')
              FROM ar_payment_schedules_all apsa, ra_customer_trx_all rct
             WHERE     apsa.status = 'CL'
                   --  AND apsa.actual_date_closed > apsa.due_date -- Commented as per CR#110
                   AND rct.customer_trx_id = apsa.customer_trx_id
                   AND rct.attribute5 = p_brand
                   AND rct.bill_to_customer_id = p_cust_acc_id
                   AND rct.org_id = p_org_id;

        CURSOR get_adl_c (p_inv_count IN NUMBER, p_start_date IN DATE, p_end_date IN DATE
                          , p_cust_acct_id IN NUMBER, p_brand IN VARCHAR2)
        IS
            SELECT ROUND ((NVL (SUM (apsa.actual_date_closed - apsa.DUE_DATE), 0) / p_inv_count), 2) adl
              FROM ar_payment_schedules_all apsa, ra_customer_trx_all rct
             WHERE     1 = 1
                   AND rct.trx_date BETWEEN p_start_date AND p_end_date
                   --  AND apsa.actual_date_closed > apsa.due_date -- Commented as per CR#110
                   AND apsa.status = 'CL'
                   AND rct.bill_to_customer_id = p_cust_acct_id
                   AND rct.attribute5 = p_brand
                   AND rct.customer_trx_id = apsa.customer_trx_id
                   AND rct.org_id = p_org_id;

        CURSOR insert_update_c (p_cust_acc_id IN NUMBER)
        IS
            SELECT DECODE (COUNT (*), 0, 'Y', 'N')
              FROM xxd_iex_metrics_tbl
             WHERE cust_account_id = p_cust_acc_id AND org_id = p_org_id;



        TYPE t_adl_quarters_rec IS TABLE OF adl_quarters_c%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_adl_quarters_rec    t_adl_quarters_rec;

        TYPE cust_acc_rec IS RECORD
        (
            cust_account_id    NUMBER,
            account_number     VARCHAR2 (100)
        );

        TYPE t_cust_acc_data_tbl IS TABLE OF cust_acc_rec
            INDEX BY PLS_INTEGER;

        l_cust_acc_data_tbl   t_cust_acc_data_tbl;


        lc_query              VARCHAR2 (32760);
        l_quarter_det         adl_quarters_c%ROWTYPE;
        ln_curr_inv_count     NUMBER;
        ln_curr_adl           NUMBER;
        lc_filter_view        VARCHAR2 (50);
        lc_brand              VARCHAR2 (30);
        lc_cur                SYS_REFCURSOR;
        lc_curr_adl_data      VARCHAR2 (1);
        lc_prev_adl_data      VARCHAR2 (1);
        ln_carry_count        NUMBER := 0;
        ln_cur_carry_count    NUMBER := 0;
    BEGIN
        --APPS.FND_CLIENT_INFO.SET_ORG_CONTEXT (ln_ou);
        --mo_global.set_policy_context('S', p_org_id);

        ld_first_pay_date     := NULL;
        ln_inv_count          := 0;
        ln_adl                := NULL;
        gc_insert_check       := NULL;
        lc_curr_adl_data      := 'N';
        lc_prev_adl_data      := 'N';

        gn_adl_rolling_days   := 90;



        /* OPEN insert_update_c (l_cust_acc_data_tbl (j).cust_account_id);

         FETCH insert_update_c INTO gc_insert_check;

         CLOSE insert_update_c;
         */
        gc_insert_check       := 'Y';


        --dbms_output.put_line('gc_insert_check=>'||gc_insert_check);

        ln_curr_adl           := NULL;
        ln_curr_inv_count     := 0;
        ln_carry_count        := 0;
        ln_cur_carry_count    := 0;
        ld_first_pay_date     := '';
        ln_inv_count          := 0;
        ln_adl                := NULL;
        lc_curr_adl_data      := 'N';
        lc_prev_adl_data      := 'N';
        lc_brand              := p_brand;
        ln_c                  := 0;

        -- dbms_output.put_line('Between Dates=>'||l_run_date-gn_adl_rolling_days||':'||l_run_date||':'||lc_brand);


        OPEN inv_count_c (TRUNC (l_run_date - gn_adl_rolling_days), TRUNC (l_run_date), p_cust_acct_id
                          , lc_brand);

        FETCH inv_count_c INTO ln_curr_inv_count;

        CLOSE inv_count_c;

        -- dbms_output.put_line('Inv Count=>'||ln_curr_inv_count||':Barnd:'||lc_brand);

        IF ln_curr_inv_count > 0
        THEN
            lc_curr_adl_data   := 'Y';

            --  dbms_output.put_line('ADL data for Brand =>'|| ln_curr_inv_count ||':'||l_run_date||':'||lc_brand);

            OPEN get_adl_c (ln_curr_inv_count, TRUNC (l_run_date - gn_adl_rolling_days), TRUNC (l_run_date)
                            , p_cust_acct_id, lc_brand);

            FETCH get_adl_c INTO ln_curr_adl;

            CLOSE get_adl_c;
        END IF;

        OPEN open_inv_Count_c (TRUNC (l_run_date - gn_adl_rolling_days), TRUNC (l_run_date), p_cust_acct_id
                               , lc_brand);

        FETCH open_inv_count_c INTO ln_c;

        CLOSE open_inv_count_c;

        IF (ln_c > 0)
        THEN
            ln_cur_carry_count   := ln_curr_inv_count;
        END IF;


        OPEN adl_quarters_c (l_run_date);

        FETCH adl_quarters_c BULK COLLECT INTO l_adl_quarters_rec;

        CLOSE adl_quarters_c;

        --                     dbms_output.put_line('Total Quarters =>'||l_adl_quarters_rec.COUNT);
        --                             dbms_output.put_line('ADL Values for Account/Brand=>'||p_cust_acct_id||':'||p_brand||CHR(10));
        --                    dbms_output.put_line('--------------------------------------------------------'||CHR(10));

        FOR i IN 1 .. l_adl_quarters_rec.COUNT
        LOOP
            l_quarter_det    := NULL;
            ln_inv_count     := 0;
            ln_adl           := NULL;
            ln_c             := 0;
            ln_carry_count   := 0;

            OPEN first_pay_date (p_cust_acct_id, lc_brand);

            FETCH first_pay_date INTO ld_first_pay_date;

            CLOSE first_pay_date;

            --                        dbms_output.put_line('First pay date=>'||ld_first_pay_date);

            IF ld_first_pay_date <= l_adl_quarters_rec (i).quarter_start_date
            THEN
                --                       dbms_output.put_line('Loop ADL data for Brand =>'|| ld_first_pay_date ||':'||l_run_date||':'||lc_brand);
                --                       dbms_output.put_line('Qtr Start and End Dates for Brand =>'|| l_adl_quarters_rec (i).quarter_start_date ||':End date:'||l_adl_quarters_rec (i).quarter_end_date||':'||lc_brand);
                OPEN inv_count_c (l_adl_quarters_rec (i).quarter_start_date, l_adl_quarters_rec (i).quarter_end_date, p_cust_acct_id
                                  , lc_brand);

                FETCH inv_count_c INTO ln_inv_count;

                CLOSE inv_count_c;

                OPEN open_inv_Count_c (l_adl_quarters_rec (i).quarter_start_date, l_adl_quarters_rec (i).quarter_end_date, p_cust_acct_id
                                       , lc_brand);

                FETCH open_inv_count_c INTO ln_c;

                CLOSE open_inv_count_c;

                IF (ln_c > 0)
                THEN
                    ln_carry_count   := ln_inv_count;
                END IF;


                -- dbms_output.put_line('Invoice Count=>'||ln_inv_count);

                IF ln_inv_count > 0
                THEN
                    lc_prev_adl_data                  := 'Y';

                    OPEN get_adl_c (ln_inv_count, l_adl_quarters_rec (i).quarter_start_date, l_adl_quarters_rec (i).quarter_end_date
                                    , p_cust_acct_id, lc_brand);

                    FETCH get_adl_c INTO ln_adl;

                    CLOSE get_adl_c;

                    l_adl_quarters_rec (i).adl        := ln_adl;
                    --snuthala l_adl_quarters_rec (i).invcount := ln_carry_count;
                    l_adl_quarters_rec (i).invcount   := ln_inv_count;
                --                                      dbms_output.put_line('ADL '||i ||'=> '|| l_adl_quarters_rec (i).adl||': Total Invoices ='||l_adl_quarters_rec (i).invcount);
                END IF;
            END IF;
        END LOOP;

        --                    dbms_output.put_line('----------------------------------------------------'||CHR(10));



        --                    dbms_output.put_line('ADL Values for Account/Brand=>'||p_cust_acct_id||':'||p_brand||CHR(10));
        --                    dbms_output.put_line('--------------------------------------------------------'||CHR(10));
        --                    dbms_output.put_line('ADL Trailing 90=>'||ln_curr_adl);
        --                    dbms_output.put_line('ADL 1=>'|| l_adl_quarters_rec (8).adl);
        --                    dbms_output.put_line('ADL 2=>'|| l_adl_quarters_rec (7).adl);
        --                    dbms_output.put_line('ADL 3=>'|| l_adl_quarters_rec (6).adl);
        --                    dbms_output.put_line('ADL 4=>'|| l_adl_quarters_rec (5).adl);
        --                    dbms_output.put_line('ADL 5=>'|| l_adl_quarters_rec (4).adl);
        --                    dbms_output.put_line('ADL 6=>'|| l_adl_quarters_rec (3).adl);
        --                    dbms_output.put_line('ADL 7=>'|| l_adl_quarters_rec (2).adl);
        --                    dbms_output.put_line('ADL 8=>'|| l_adl_quarters_rec (1).adl);

        IF lc_curr_adl_data = 'Y' OR lc_prev_adl_data = 'Y'
        THEN
            INSERT_UPDATE (
                p_insert_update_flag   => 'Y',
                p_cust_account_id      => p_cust_acct_id,
                p_org_id               => p_org_id,
                p_adl_q1               => l_adl_quarters_rec (8).adl,
                p_adl_q2               => l_adl_quarters_rec (7).adl,
                p_adl_q3               => l_adl_quarters_rec (6).adl,
                p_adl_q4               => l_adl_quarters_rec (5).adl,
                p_adl_q5               => l_adl_quarters_rec (4).adl,
                p_adl_q6               => l_adl_quarters_rec (3).adl,
                p_adl_q7               => l_adl_quarters_rec (2).adl,
                p_adl_q8               => l_adl_quarters_rec (1).adl,
                p_curr_adl             => ln_curr_adl,
                p_attribute1           => lc_brand,
                p_attribute2           => p_account_number,
                p_attribute3           => l_adl_quarters_rec (1).invcount,
                p_attribute4           => l_adl_quarters_rec (2).invcount,
                p_attribute5           => l_adl_quarters_rec (3).invcount,
                p_attribute6           => l_adl_quarters_rec (4).invcount,
                p_attribute7           => l_adl_quarters_rec (5).invcount,
                p_attribute8           => l_adl_quarters_rec (6).invcount,
                p_attribute9           => l_adl_quarters_rec (7).invcount,
                p_attribute10          => l_adl_quarters_rec (8).invcount,
                p_attribute11          => ln_curr_inv_count,
                P_attribute12          => p_org_name);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('In Exception Start .');
            DBMS_OUTPUT.put_line (
                   'Cust_acct_id : '
                || P_CUST_ACCT_ID
                || CHR (9)
                || 'Brand : '
                || lc_brand);
            DBMS_OUTPUT.put_line ('Error : ' || SQLERRM);
            DBMS_OUTPUT.put_line ('In Exception End .');
    END POPULATE_ADL;



    PROCEDURE INSERT_UPDATE (p_insert_update_flag   IN VARCHAR2,
                             p_cust_account_id      IN NUMBER,
                             p_org_id               IN NUMBER,
                             p_adl_q1               IN NUMBER DEFAULT NULL,
                             p_adl_q2               IN NUMBER DEFAULT NULL,
                             p_adl_q3               IN NUMBER DEFAULT NULL,
                             p_adl_q4               IN NUMBER DEFAULT NULL,
                             p_adl_q5               IN NUMBER DEFAULT NULL,
                             p_adl_q6               IN NUMBER DEFAULT NULL,
                             p_adl_q7               IN NUMBER DEFAULT NULL,
                             p_adl_q8               IN NUMBER DEFAULT NULL,
                             p_curr_adl             IN NUMBER DEFAULT NULL,
                             p_adl_variance         IN NUMBER DEFAULT NULL,
                             p_aging_bucket_score   IN NUMBER DEFAULT NULL,
                             p_aging_bucket         IN VARCHAR2 DEFAULT NULL,
                             p_booked_order_score   IN NUMBER DEFAULT NULL,
                             p_last_payment_score   IN NUMBER DEFAULT NULL,
                             p_adl_score            IN NUMBER DEFAULT NULL,
                             p_score                IN NUMBER DEFAULT NULL,
                             p_mapped_score         IN NUMBER DEFAULT NULL,
                             p_attribute_category   IN VARCHAR2 DEFAULT NULL,
                             p_attribute1           IN VARCHAR2 DEFAULT NULL,
                             p_attribute2           IN VARCHAR2 DEFAULT NULL,
                             p_attribute3           IN VARCHAR2 DEFAULT NULL,
                             p_attribute4           IN VARCHAR2 DEFAULT NULL,
                             p_attribute5           IN VARCHAR2 DEFAULT NULL,
                             p_attribute6           IN VARCHAR2 DEFAULT NULL,
                             p_attribute7           IN VARCHAR2 DEFAULT NULL,
                             p_attribute8           IN VARCHAR2 DEFAULT NULL,
                             p_attribute9           IN VARCHAR2 DEFAULT NULL,
                             p_attribute10          IN VARCHAR2 DEFAULT NULL,
                             p_attribute11          IN VARCHAR2 DEFAULT NULL,
                             p_attribute12          IN VARCHAR2 DEFAULT NULL,
                             p_attribute13          IN VARCHAR2 DEFAULT NULL,
                             p_attribute14          IN VARCHAR2 DEFAULT NULL,
                             p_attribute15          IN VARCHAR2 DEFAULT NULL,
                             p_attribute16          IN VARCHAR2 DEFAULT NULL,
                             p_attribute17          IN VARCHAR2 DEFAULT NULL,
                             p_attribute18          IN VARCHAR2 DEFAULT NULL,
                             p_attribute19          IN VARCHAR2 DEFAULT NULL,
                             p_attribute20          IN VARCHAR2 DEFAULT NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF p_insert_update_flag = 'Y'
        THEN
            INSERT INTO xxd_iex_metrics_tbl (cust_account_id,
                                             org_id,
                                             adl_q1,
                                             adl_q2,
                                             adl_q3,
                                             adl_q4,
                                             adl_q5,
                                             adl_q6,
                                             adl_q7,
                                             adl_q8,
                                             curr_adl,
                                             adl_variance,
                                             aging_bucket_score,
                                             aging_bucket,
                                             booked_order_score,
                                             last_payment_score,
                                             adl_score,
                                             score,
                                             mapped_score,
                                             attribute_category,
                                             attribute1,
                                             attribute2,
                                             attribute3,
                                             attribute4,
                                             attribute5,
                                             attribute6,
                                             attribute7,
                                             attribute8,
                                             attribute9,
                                             attribute10,
                                             attribute11,
                                             attribute12,
                                             attribute13,
                                             attribute14,
                                             attribute15,
                                             attribute16,
                                             attribute17,
                                             attribute18,
                                             attribute19,
                                             attribute20,
                                             created_by,
                                             creation_date,
                                             last_updated_by,
                                             last_update_date)
                 VALUES (p_cust_account_id, p_org_id, p_adl_q1,
                         p_adl_q2, p_adl_q3, p_adl_q4,
                         p_adl_q5, p_adl_q6, p_adl_q7,
                         p_adl_q8, p_curr_adl, p_adl_variance,
                         p_aging_bucket_score, p_aging_bucket, p_booked_order_score, p_last_payment_score, p_adl_score, p_score, p_mapped_score, p_attribute_category, p_attribute1, p_attribute2, p_attribute3, p_attribute4, p_attribute5, p_attribute6, p_attribute7, p_attribute8, p_attribute9, p_attribute10, p_attribute11, p_attribute12, p_attribute13, p_attribute14, p_attribute15, p_attribute16, p_attribute17, p_attribute18, p_attribute19, p_attribute20, gn_user_id, gd_sysdate
                         , gn_user_id, gd_sysdate);
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.put_line (FND_FILE.LOG,
                               'Exception at INSERT_UPDATE' || SQLERRM);
    END INSERT_UPDATE;
END XXD_ADL_EXTRACT_PKG;
/
