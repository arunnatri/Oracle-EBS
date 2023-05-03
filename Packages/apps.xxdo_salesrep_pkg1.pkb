--
-- XXDO_SALESREP_PKG1  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SALESREP_PKG1"
IS
    /*
    *********************************************************************************************
    * Package         : XXDO_SALESREP_PKG
    * Author          : BT Technology Team
    * Created         : 20-MAR-2015
    * Description     :THIS PACKAGE IS USED  TO INSERT THE SALESREP DATA INTO
    *                  CUSTOM TABLE
    *
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *-----------------------------------------------------------------------------------------------
    *     20-MAR-2015 BT Technology Team     V1.1         Development
    ************************************************************************************************/
    /*-*********************************************Global Variables********************************************************************/
    --gn_user_id       NUMBER(15) :=APPS.FND_GLOBAL.USER_ID;
    --gn_request_id    NUMBER(15) :=APPS.FND_GLOBAL.CONC_REQUEST_ID;
    gn_error                   NUMBER := -1;
    gn_success                 NUMBER := 0;
    gc_status_error   CONSTANT VARCHAR2 (20) := 'E';
    gc_status_val     CONSTANT VARCHAR2 (20) := 'VALIDATED';
    gn_salesreo_tot_rec        NUMBER := 0;
    gn_salesrep_val_rec        NUMBER := 0;
    gn_salesrep_err_rec        NUMBER := 0;

    ---------------------------------------------------end of Global Variables-----------------------------------------------------------
    /*-*********************************************Global Cursor***********************************************************************/
    CURSOR GCU_SALESREP IS
        SELECT *
          FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST ST
         WHERE     NOT STATUS IN ('C', 'D', 'E',
                                  'AC')
               AND EXISTS
                       (SELECT 1
                          FROM hz_cust_accounts
                         WHERE account_number =
                               st.customer_number || '-' || st.brand)
               AND EXISTS
                       (SELECT 1
                          FROM XXD_AR_CUST_INT_1206_T tab
                         WHERE     1 = 1
                               AND tab.customer_name = st.customer_name --AND tab.customer_number = 14335695
                               AND tab.customer_number = st.customer_number)
               AND SITE_use_id IS NOT NULL     --AND customer_number = 1378795
                                          ;

    -----------------------------------------------------end of Global Cursors-------------------------------------------------------------------
    /*-********************************************************************************************************************************
    Start of Debug Log Procedures
    **********************************************************************************************************************************/
    PROCEDURE DEBUG_LOG (p_msg VARCHAR2)
    IS
    BEGIN
        NULL;
    --apps.FND_FILE.PUT_LINE (apps.FND_FILE.LOG, p_msg);
    END DEBUG_LOG;

    -----------------------------------------------------end of debug log-------------------------------------------------------------------
    /*-*********************************************************************************************************************************
    Start of Print output Procedures
    ***********************************************************************************************************************************/
    PROCEDURE PRINT_OUT (p_msg VARCHAR2)
    IS
    BEGIN
        apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT, p_msg);
    END PRINT_OUT;

    -----------------------------------------------------end of print out put---------------------------------------------------------------
    /*
    ********************************************************************************************************************************
    Start of UPDATE Procedures
    **********************************************************************************************************************************/
    PROCEDURE UPDATE_SALESREP (X_ERRBUF OUT VARCHAR2, X_RETCODE OUT NUMBER, P_SATUS IN VARCHAR2, P_ERR_MSG IN VARCHAR2 DEFAULT NULL, P_RECORD_NO IN NUMBER, P_SUB_CLASS VARCHAR2 DEFAULT NULL, P_SITE_USE_ID NUMBER DEFAULT NULL, P_SITE_USE_CODE VARCHAR2 DEFAULT NULL, P_SALESREP_NUMBER VARCHAR2 DEFAULT NULL, P_SALESREP_NAME VARCHAR2 DEFAULT NULL, P_SALESREP_ID NUMBER DEFAULT NULL, P_OU_NAME VARCHAR2 DEFAULT NULL, P_ORG_ID NUMBER DEFAULT NULL, P_DIVISION VARCHAR2 DEFAULT NULL, P_DEPARTMENT VARCHAR2 DEFAULT NULL, P_CUSTOMER_SITE VARCHAR2 DEFAULT NULL, P_CUSTOMER_NUMBER VARCHAR2 DEFAULT NULL, P_CUSTOMER_NAME VARCHAR2 DEFAULT NULL, P_CUSTOMER_ID NUMBER DEFAULT NULL, P_CLASS VARCHAR2 DEFAULT NULL, P_BRAND VARCHAR2 DEFAULT NULL
                               , P_ACCOUNT_NAME VARCHAR2 DEFAULT NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lc_err_msg   VARCHAR2 (1000) := NULL;
        lc_STATUS    VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'P_RECORD_NO ' || P_RECORD_NO);
        fnd_file.put_line (fnd_file.LOG, 'P_SATUS ' || P_SATUS);

        UPDATE XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
           SET STATUS = P_SATUS, ERROR_MSG = SUBSTR (NVL (ERROR_MSG || ' ' || P_ERR_MSG, ERROR_MSG), 1, 1024), X_SUB_CLASS = NVL (P_SUB_CLASS, X_SUB_CLASS),
               X_SITE_USE_ID = NVL (P_SITE_USE_ID, X_SITE_USE_ID), X_SITE_USE_CODE = NVL (P_SITE_USE_CODE, X_SITE_USE_CODE), X_SALESREP_NUMBER = NVL (P_SALESREP_NUMBER, X_SALESREP_NUMBER),
               X_SALESREP_NAME = NVL (P_SALESREP_NAME, X_SALESREP_NAME), X_SALESREP_ID = NVL (P_SALESREP_ID, X_SALESREP_ID), X_OU_NAME = NVL (P_OU_NAME, X_OU_NAME),
               X_ORG_ID = NVL (P_ORG_ID, X_ORG_ID), X_DIVISION = NVL (P_DIVISION, X_DIVISION), X_DEPARTMENT = NVL (P_DEPARTMENT, X_DEPARTMENT),
               X_CUSTOMER_SITE = NVL (P_CUSTOMER_SITE, X_CUSTOMER_SITE), X_CUSTOMER_NUMBER = NVL (P_CUSTOMER_NUMBER, X_CUSTOMER_NUMBER), X_CUSTOMER_NAME = NVL (P_CUSTOMER_NAME, X_CUSTOMER_NAME),
               X_CUSTOMER_ID = NVL (P_CUSTOMER_ID, X_CUSTOMER_ID), X_CLASS = NVL (P_CLASS, X_CLASS), X_BRAND = NVL (P_BRAND, X_BRAND),
               X_ACCOUNT_NAME = NVL (P_ACCOUNT_NAME, X_ACCOUNT_NAME)
         WHERE RECORD_NUMBER = P_RECORD_NO;

        COMMIT;
        X_RETCODE   := 0;



        --select STATUS into lc_STATUS from XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST        WHERE RECORD_NUMBER = P_RECORD_NO;

        fnd_file.put_line (fnd_file.LOG, 'lc_STATUS in ' || lc_STATUS);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_log ('Unexpected Exception in UPDATEING : ' || SQLERRM);
            lc_err_msg   :=
                ' Unexpected error occured in UPDATEING :' || SQLERRM;

            fnd_file.put_line (fnd_file.LOG, 'Error ' || SQLERRM);


            COMMIT;
            x_retcode   := gn_error;
            X_ERRBUF    := LC_ERR_MSG;
    END UPDATE_SALESREP;

    ----------------------------------------------end of UPDATE procedure-------------------------
    /*-******************************************************************************************************************************
    start VALIDATE_JOB Program
    *********************************************************************************************************************************/
    PROCEDURE VALIDATE_SALESREP (X_errbuf OUT VARCHAR2, X_retcode OUT NUMBER)
    IS
        LC_ERRBUF                VARCHAR2 (1000) := NULL;
        LN_RETCODE               NUMBER := 0;
        LB_VALID                 BOOLEAN;
        LC_ERR_MSG               VARCHAR2 (2000);
        lc_org_name              VARCHAR2 (200);
        Ln_ORG_ID                NUMBER (32);
        LN_SALES_REP_id          NUMBER (10);
        LC_SALES_REP_NUM         VARCHAR2 (100);
        LN_BRAND                 NUMBER (10);
        LN_CUST_ACCT_ID          NUMBER;
        LN_DIVISION              NUMBER (10);
        LN_SUB_CLASS             NUMBER;
        LN_COUNT                 NUMBER;
        LN_CUSTOMER_NAME         VARCHAR2 (100);
        ln_counter               NUMBER;
        lc_account_name          VARCHAR2 (200);
        ln_site_id               NUMBER;
        lc_location              hz_cust_site_uses_all.location%TYPE;



        CURSOR c_org_id (p_org_name VARCHAR2)
        IS
            SELECT organization_id
              FROM hr_operating_units
             WHERE name = p_org_name;

        CURSOR c_account_det (p_acc_number VARCHAR2)
        IS
            SELECT cust_account_id, account_name
              FROM HZ_CUST_ACCOUNTS
             WHERE ACCOUNT_NUMBER = p_acc_number;

        CURSOR c_sales_rep_det (P_sales_rep_name VARCHAR2, p_org_id NUMBER)
        IS
            SELECT DISTINCT JRS.salesrep_id, jrs.salesrep_number
              FROM jtf_rs_resource_extns_vl JRRE, jtf_rs_salesreps JRS
             WHERE     Jrs.Resource_Id = Jrre.Resource_Id
                   AND jrs.org_id = p_org_id
                   AND UPPER (JRRE.resource_name) = p_sales_rep_name;

        /* CURSOR c_site_det (p_cust_acct_id    NUMBER,
                            p_SITE_CODE       VARCHAR2,
                            P_location        VARCHAR2,
                            p_org_id          NUMBER)
         IS
            SELECT DISTINCT site_use_id
              FROM (SELECT hcsu.site_use_id site_use_id
                      FROM hz_cust_accounts_all hca,
                           hz_cust_acct_sites_all hcas,
                           hz_cust_site_uses_all hcsu
                     WHERE     hca.cust_account_id = p_cust_acct_id
                           AND hca.cust_account_id = hcas.cust_account_id
                           AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                           AND hcas.org_id = p_org_id
                           AND hcsu.site_use_code = p_SITE_CODE
                           AND hca.status = 'A'
                           AND hcas.status = 'A'
                           AND hcsu.status = 'A'
                           AND NVL (hcsu.location, ' ') =
                                  NVL (P_location, NVL (hcsu.location, ' '))
                    UNION
                    SELECT hcsu.site_use_id
                      FROM (SELECT NVL (HCAR.related_cust_account_id,
                                        HCA.cust_account_id)
                                      related_cust_account_id,
                                   HCA.status,
                                   Hca.Cust_Account_Id,
                                   hca.account_name,
                                   hca.account_number
                              FROM hz_cust_accounts_all HCA,
                                   hz_cust_acct_relate_all HCAR
                             WHERE     HCA.cust_account_id =
                                          HCAR.cust_account_id(+)
                                   AND HCAR.status(+) = 'A'
                                   AND HCA.cust_account_id = p_cust_acct_id) hca,
                           hz_cust_acct_sites_all hcas,
                           hz_cust_site_uses_all hcsu
                     WHERE     hca.related_cust_account_id =
                                  hcas.cust_account_id
                           AND hcas.org_id = p_org_id
                           AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                           AND hcsu.site_use_code = p_SITE_CODE
                           --AND hcsu.primary_flag = 'Y'
                           AND hca.status = 'A'
                           AND hcas.status = 'A'
                           AND hcsu.status = 'A'
                           AND NVL (hcsu.location, ' ') =
                                  NVL (P_location, NVL (hcsu.location, ' '))
                    UNION
                    SELECT hcsu.site_use_id
                      FROM hz_cust_accounts_all hca,
                           hz_cust_acct_sites_all hcas,
                           hz_cust_site_uses_all hcsu
                     WHERE     hca.cust_account_id = p_cust_acct_id
                           AND hca.cust_account_id = hcas.cust_account_id
                           AND hcas.org_id = p_org_id
                           AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                           AND hcsu.site_use_code = p_SITE_CODE
                           --AND hcsu.primary_flag = 'Y'
                           AND hca.status = 'A'
                           AND hcas.status = 'A'
                           AND hcsu.status = 'A'
                           AND NVL (hcsu.location, ' ') =
                                  NVL (P_location, NVL (hcsu.location, ' ')));*/

        /*CURSOR c_bill_to_site_det (p_cust_acct_id    NUMBER,
                                   P_location        VARCHAR2,
                                   p_org_id          NUMBER)
        IS
           SELECT DISTINCT site_use_id
             FROM (SELECT hcsu.site_use_id site_use_id
                     FROM hz_cust_accounts_all hca,
                          hz_cust_acct_sites_all hcas,
                          hz_cust_site_uses_all hcsu
                    WHERE     hca.cust_account_id = p_cust_acct_id
                          AND hca.cust_account_id = hcas.cust_account_id
                          AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                          AND hcas.org_id = p_org_id
                          --AND hcsu.primary_flag = 'Y'
                          AND hcsu.site_use_code = 'BILL_TO'
                          AND hca.status = 'A'
                          AND hcas.status = 'A'
                          AND hcsu.status = 'A'
                          AND NVL (hcsu.location, ' ') =
                                 NVL (P_location, NVL (hcsu.location, ' ')));

        CURSOR c_bill_to_site_det (p_cust_acct_id    NUMBER,
                                   P_location        VARCHAR2,
                                   p_org_id          NUMBER)
        IS
           SELECT DISTINCT site_use_id
             FROM (SELECT hcsu.site_use_id site_use_id
                     FROM hz_cust_accounts_all hca,
                          hz_cust_acct_sites_all hcas,
                          hz_cust_site_uses_all hcsu
                    WHERE     hca.cust_account_id = p_cust_acct_id
                          AND hca.cust_account_id = hcas.cust_account_id
                          AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                          AND hcas.org_id = p_org_id
                          --AND hcsu.primary_flag = 'Y'
                          AND hcsu.site_use_code = 'BILL_TO'
                          AND hca.status = 'A'
                          AND hcas.status = 'A'
                          AND hcsu.status = 'A'
                          AND NVL (hcsu.location, ' ') =
                                 NVL (P_location, NVL (hcsu.location, ' ')));

        */

        CURSOR c_bill_to_site_det (P_old_site_use_id NUMBER, p_brand VARCHAR2, p_site_use_code VARCHAR2)
        IS
            SELECT site_use_id, location
              FROM hz_cust_site_uses_all
             WHERE     ORIG_SYSTEM_REFERENCE =
                       P_old_site_use_id || '-' || p_brand
                   AND site_use_code = p_site_use_code;



        CURSOR c_ship_to_site_det (p_cust_acct_id NUMBER, P_location VARCHAR2, p_org_id NUMBER)
        IS
            SELECT DISTINCT hcsu.site_use_id
              FROM (SELECT NVL (HCAR.related_cust_account_id, HCA.cust_account_id) related_cust_account_id, HCA.status, Hca.Cust_Account_Id,
                           hca.account_name, hca.account_number
                      FROM hz_cust_accounts_all HCA, hz_cust_acct_relate_all HCAR
                     WHERE     HCA.cust_account_id = HCAR.cust_account_id(+)
                           AND HCAR.status(+) = 'A'
                           AND HCA.cust_account_id = p_cust_acct_id) hca,
                   hz_cust_acct_sites_all hcas,
                   hz_cust_site_uses_all hcsu
             WHERE     hca.related_cust_account_id = hcas.cust_account_id
                   AND hcas.org_id = p_org_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_code = 'SHIP_TO'
                   --AND hcsu.primary_flag = 'Y'
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcsu.status = 'A'
                   AND NVL (hcsu.location, ' ') =
                       NVL (P_location, NVL (hcsu.location, ' '));

        CURSOR Get_insert_rec_c IS
            SELECT *
              FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
             WHERE     BRAND LIKE 'UGG%'
                   AND OPERATING_UNIT = 'Deckers US'
                   AND NOT STATUS IN ('C', 'D', 'E',
                                      'AC');

        lcu_Get_insert_rec_c     Get_insert_rec_c%ROWTYPE;

        CURSOR get_bil_to_c (p_brand_acct VARCHAR2)
        IS
            SELECT hcsu.LOCATION, hcsu.SITE_USE_ID
              FROM hz_cust_accounts_all hca, hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu,
                   hr_operating_units hou
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hou.organization_id = hcsu.org_id
                   AND hou.name = 'Deckers US OU'
                   AND hca.account_number = p_brand_acct;

        lcu_get_bil_to_c         get_bil_to_c%ROWTYPE;
        lc_STATUS                VARCHAR2 (100);


        CURSOR get_dup_sale_rep_c IS
              SELECT OPERATING_UNIT, BRAND, CUSTOMER_NAME,
                     CUSTOMER_NUMBER, SITE_CODE, SITE_LOCATION,
                     DIVISION, DEPARTMENT, CLASS,
                     SUB_CLASS
                FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
               WHERE NOT STATUS IN ('C', 'D', 'E',
                                    'AC')
            GROUP BY OPERATING_UNIT, BRAND, CUSTOMER_NAME,
                     CUSTOMER_NUMBER, SITE_CODE, SITE_LOCATION,
                     DIVISION, DEPARTMENT, CLASS,
                     SUB_CLASS
              HAVING COUNT (1) > 1;

        lcu_get_dup_sale_rep_c   get_dup_sale_rep_c%ROWTYPE;
    BEGIN
        ln_counter   := 0;

        --fnd_file.put_line (fnd_file.LOG, 'Test1');

        UPDATE XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
           SET status   = 'D'
         WHERE ROWID NOT IN (  SELECT MAX (ROWID)
                                 FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
                             GROUP BY OPERATING_UNIT, BRAND, CUSTOMER_NAME,
                                      CUSTOMER_NUMBER, SALES_REP, SALESREP_NAME,
                                      SITE_CODE, SITE_LOCATION, DIVISION,
                                      DEPARTMENT, CLASS, SUB_CLASS);

        COMMIT;

        --Start
        OPEN get_dup_sale_rep_c;

        LOOP
            --fnd_file.put_line (fnd_file.LOG, 'Test11');
            FETCH get_dup_sale_rep_c INTO lcu_get_dup_sale_rep_c;

            EXIT WHEN get_dup_sale_rep_c%NOTFOUND;

            UPDATE XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
               SET status = 'E', ERROR_MSG = 'Multiple Salesreps Found for Customer Site '
             WHERE     NVL (OPERATING_UNIT, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.OPERATING_UNIT, 'X')
                   AND NVL (BRAND, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.BRAND, 'X')
                   AND NVL (CUSTOMER_NAME, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.CUSTOMER_NAME, 'X')
                   AND NVL (CUSTOMER_NUMBER, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.CUSTOMER_NUMBER, 'X')
                   AND NVL (SITE_CODE, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.SITE_CODE, 'X')
                   AND NVL (SITE_LOCATION, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.SITE_LOCATION, 'X')
                   AND NVL (DIVISION, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.DIVISION, 'X')
                   AND NVL (DEPARTMENT, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.DEPARTMENT, 'X')
                   AND NVL (CLASS, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.CLASS, 'X')
                   AND NVL (SUB_CLASS, 'X') =
                       NVL (lcu_get_dup_sale_rep_c.SUB_CLASS, 'X')
                   AND status NOT IN ('D', 'E');
        --fnd_file.put_line (fnd_file.LOG, 'Test12 '||SQL%ROWCOUNT);
        END LOOP;

        CLOSE get_dup_sale_rep_c;

        COMMIT;

        --End

        --fnd_file.put_line (fnd_file.LOG, 'Test3');

        UPDATE XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST st
           SET ERROR_MSG = 'Account does not exists in the system', STATUS = 'E'
         WHERE NOT EXISTS
                   (SELECT 1
                      FROM hz_cust_accounts
                     WHERE account_number =
                           st.customer_number || '-' || st.brand);

        --fnd_file.put_line (fnd_file.LOG, 'Test4');

        UPDATE XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST st
           SET ERROR_MSG = 'Customer number and customer name combination does not exist in the system', STATUS = 'E'
         WHERE NOT EXISTS
                   (SELECT 1
                      FROM XXD_AR_CUST_INT_1206_T tab
                     WHERE     tab.customer_name = st.customer_name
                           AND tab.customer_number = st.customer_number);



        COMMIT;

        --fnd_file.put_line (fnd_file.LOG, 'Test5');

        --Start modification
        OPEN Get_insert_rec_c;

        LOOP
            --fnd_file.put_line (fnd_file.LOG, 'Test6');

            FETCH Get_insert_rec_c INTO lcu_Get_insert_rec_c;

            EXIT WHEN Get_insert_rec_c%NOTFOUND;

            OPEN get_bil_to_c (
                   lcu_Get_insert_rec_c.CUSTOMER_NUMBER
                || '-'
                || lcu_Get_insert_rec_c.BRAND);



            LOOP
                FETCH get_bil_to_c INTO lcu_get_bil_to_c;

                EXIT WHEN get_bil_to_c%NOTFOUND;

                INSERT INTO XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST (
                                record_number,
                                OPERATING_UNIT,
                                BRAND,
                                CUSTOMER_NAME,
                                CUSTOMER_NUMBER,
                                SALES_REP,
                                SALESREP_NAME,
                                SITE_CODE,
                                SITE_LOCATION,
                                SITE_USE_ID,
                                X_SITE_USE_ID,
                                X_CUSTOMER_SITE,
                                X_SITE_USE_CODE,
                                DIVISION,
                                DEPARTMENT,
                                CLASS,
                                SUB_CLASS,
                                STATUS)
                         VALUES (XXDO.XXDO_SALESREP_CONV_STG_S.NEXTVAL,
                                 lcu_Get_insert_rec_c.OPERATING_UNIT,
                                 lcu_Get_insert_rec_c.BRAND,
                                 lcu_Get_insert_rec_c.CUSTOMER_NAME,
                                 lcu_Get_insert_rec_c.CUSTOMER_NUMBER,
                                 lcu_Get_insert_rec_c.SALES_REP,
                                 lcu_Get_insert_rec_c.SALESREP_NAME,
                                 lcu_Get_insert_rec_c.SITE_CODE,
                                 lcu_get_bil_to_c.LOCATION,
                                 lcu_get_bil_to_c.SITE_USE_ID,
                                 lcu_get_bil_to_c.SITE_USE_ID,
                                 lcu_get_bil_to_c.LOCATION,
                                 lcu_Get_insert_rec_c.SITE_CODE,
                                 lcu_Get_insert_rec_c.DIVISION,
                                 lcu_Get_insert_rec_c.DEPARTMENT,
                                 lcu_Get_insert_rec_c.CLASS,
                                 lcu_Get_insert_rec_c.SUB_CLASS,
                                 'NEW');
            END LOOP;

            CLOSE get_bil_to_c;
        END LOOP;

        CLOSE Get_insert_rec_c;

        COMMIT;

        --End  modification



        FOR v_SALESREP IN GCU_SALESREP
        LOOP
            LC_ERR_MSG             := NULL;
            LB_VALID               := TRUE;
            Ln_ORG_ID              := NULL;
            LN_SALES_REP_id        := NULL;
            LN_BRAND               := NULL;
            LN_CUST_ACCT_ID        := NULL;
            LN_SUB_CLASS           := NULL;
            LN_COUNT               := 0;
            LN_CUSTOMER_NAME       := NULL;
            lc_org_name            := NULL;
            lc_account_name        := NULL;
            ln_site_id             := NULL;
            LC_SALES_REP_NUM       := NULL;


            /* =================================================================================================================================
          Validation for Operating_Unit
          =================================================================================================================================== */

            IF v_SALESREP.OPERATING_UNIT IS NOT NULL
            THEN
                BEGIN
                    SELECT ATTRIBUTE1
                      INTO lc_org_name
                      FROM fnd_lookup_values
                     WHERE     LOOKUP_TYPE = 'XXD_1206_OU_MAPPING'
                           AND MEANING = v_SALESREP.OPERATING_UNIT
                           AND LANGUAGE = USERENV ('LANG');
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        LB_VALID   := FALSE;
                        LC_ERR_MSG   :=
                               LC_ERR_MSG
                            || '. '
                            || 'OPERATING UNIT '
                            || v_SALESREP.OPERATING_UNIT
                            || ' does not exist in EBS .';
                        debug_log (LC_ERR_MSG);
                    WHEN OTHERS
                    THEN
                        LB_VALID   := FALSE;
                        LC_ERR_MSG   :=
                               LC_ERR_MSG
                            || '. '
                            || 'Other Exception while validating OPERATING UNIT: '
                            || v_SALESREP.OPERATING_UNIT
                            || '-->'
                            || SQLERRM
                            || '.';
                        debug_log (LC_ERR_MSG);
                END;
            END IF;



            debug_log ('lc_org_name  : ' || lc_org_name);
            v_SALESREP.x_OU_NAME   := lc_org_name;

            OPEN c_org_id (lc_org_name);

            FETCH c_org_id INTO ln_org_id;

            CLOSE c_org_id;

            debug_log ('ln_org_id  : ' || ln_org_id);
            v_SALESREP.x_Org_id    := ln_org_id;


            /* =========================================================================================================
              Validation for CUSTOMER ACCOUNT
              ========================================================================================================= */
            IF v_SALESREP.CUSTOMER_NUMBER IS NOT NULL
            THEN
                IF v_SALESREP.BRAND IS NOT NULL
                THEN
                    BEGIN
                        OPEN c_account_det (
                            v_SALESREP.CUSTOMER_NUMBER || '-' || v_SALESREP.BRAND);

                        FETCH c_account_det INTO LN_CUST_ACCT_ID, lc_account_name;

                        CLOSE c_account_det;

                        debug_log ('LN_CUST_ACCT_ID : ' || LN_CUST_ACCT_ID);
                        debug_log ('lc_account_name : ' || lc_account_name);

                        v_SALESREP.x_account_name   := lc_account_name;
                        v_SALESREP.x_customer_id    := LN_CUST_ACCT_ID;
                        v_SALESREP.x_brand          := v_SALESREP.BRAND;
                        v_SALESREP.x_CUSTOMER_NUMBER   :=
                               v_SALESREP.CUSTOMER_NUMBER
                            || '-'
                            || v_SALESREP.BRAND;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            --fnd_file.put_line (fnd_file.LOG, 'Test33');

                            IF c_account_det%ISOPEN
                            THEN
                                CLOSE c_account_det;
                            END IF;

                            LB_VALID   := FALSE;
                            LC_ERR_MSG   :=
                                   LC_ERR_MSG
                                || '. '
                                || 'customer account '
                                || v_SALESREP.CUSTOMER_NUMBER
                                || '-'
                                || v_SALESREP.BRAND
                                || ' does not exist .';
                            debug_log (LC_ERR_MSG);
                        WHEN OTHERS
                        THEN
                            IF c_account_det%ISOPEN
                            THEN
                                CLOSE c_account_det;
                            END IF;

                            -- ln_item_id:=NULL;
                            LB_VALID   := FALSE;
                            LC_ERR_MSG   :=
                                   LC_ERR_MSG
                                || '. '
                                || 'Other Exception while validating customer account: '
                                || v_SALESREP.CUSTOMER_NUMBER
                                || '-'
                                || v_SALESREP.BRAND
                                || '-->'
                                || SQLERRM
                                || '.';
                            debug_log (LC_ERR_MSG);
                    END;
                END IF;
            END IF;


            /* =========================================================================================================
             Validation for CUSTOMER_SITE
             ==========================================================================================================*/
            IF     v_salesrep.brand = 'UGG'
               AND v_salesrep.OPERATING_UNIT = 'Deckers US'
            THEN
                NULL;
            --v_SALESREP.x_SITE_USE_ID := v_SALESREP.SITE_USE_ID;
            ELSIF v_salesrep.site_use_id IS NOT NULL
            THEN
                BEGIN
                    OPEN c_bill_to_site_det (v_SALESREP.site_use_id,
                                             v_SALESREP.brand,
                                             v_SALESREP.SITE_CODE);

                    FETCH c_bill_to_site_det INTO ln_site_id, lc_location;

                    CLOSE c_bill_to_site_det;

                    IF ln_site_id IS NULL OR ln_site_id = 0
                    THEN
                        LB_VALID   := FALSE;
                        LC_ERR_MSG   :=
                               LC_ERR_MSG
                            || '. '
                            || 'site   '
                            || v_SALESREP.SITE_CODE
                            || '. '
                            || 'location   '
                            || v_SALESREP.SITE_location
                            || ' doesnot not exists for account '
                            || LN_CUST_ACCT_ID;
                        debug_log (LC_ERR_MSG);
                    ELSE
                        v_SALESREP.x_SITE_USE_ID     := ln_site_id;
                        v_SALESREP.x_CUSTOMER_SITE   := lc_location;
                        v_SALESREP.x_SITE_USE_CODE   := v_SALESREP.SITE_CODE;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        IF c_bill_to_site_det%ISOPEN
                        THEN
                            CLOSE c_bill_to_site_det;
                        END IF;

                        --fnd_file.put_line (fnd_file.LOG, 'Test34');

                        LB_VALID   := FALSE;
                        LC_ERR_MSG   :=
                               LC_ERR_MSG
                            || '. '
                            || 'SITE_CODE '
                            || v_SALESREP.SITE_CODE
                            || ' does not exist .';
                        debug_log (LC_ERR_MSG);
                    WHEN OTHERS
                    THEN
                        IF c_bill_to_site_det%ISOPEN
                        THEN
                            CLOSE c_bill_to_site_det;
                        END IF;

                        -- ln_item_id:=NULL;
                        LB_VALID   := FALSE;
                        LC_ERR_MSG   :=
                               LC_ERR_MSG
                            || '. '
                            || 'Other Exception while validating SITE_CODE: '
                            || v_SALESREP.SITE_CODE
                            || '-->'
                            || SQLERRM
                            || '.';
                        debug_log (LC_ERR_MSG);
                END;
            END IF;



            /* IF     v_salesrep.site_code IS NOT NULL
                AND v_salesrep.site_location IS NOT NULL
             THEN
                BEGIN
                   IF v_salesrep.site_code = 'BILL_TO'
                   THEN
               OPEN c_bill_to_site_det (LN_CUST_ACCT_ID,
                                               v_SALESREP.site_location,
                                               ln_org_id);



                      FETCH c_bill_to_site_det INTO ln_site_id;

                      CLOSE c_bill_to_site_det;
                   END IF;

                   IF v_salesrep.site_code = 'SHIP_TO'
                   THEN
                      OPEN c_ship_to_site_det (LN_CUST_ACCT_ID,
                                               v_SALESREP.site_location,
                                               ln_org_id);

                      FETCH c_ship_to_site_det INTO ln_site_id;

                      CLOSE c_ship_to_site_det;
                   END IF;


                   debug_log ('ln_site_id : ' || ln_site_id);

                   IF ln_site_id IS NULL OR ln_site_id = 0
                   THEN
                      LB_VALID := FALSE;
                      LC_ERR_MSG :=
                            LC_ERR_MSG
                         || '. '
                         || 'site   '
                         || v_SALESREP.SITE_CODE
                         || '. '
                         || 'location   '
                         || v_SALESREP.SITE_location
                         || ' doesnot not exists for account '
                         || LN_CUST_ACCT_ID;
                      debug_log (LC_ERR_MSG);
                   ELSE
                      v_SALESREP.x_SITE_USE_ID := ln_site_id;
                      v_SALESREP.x_CUSTOMER_SITE := v_SALESREP.SITE_location;
                      v_SALESREP.x_SITE_USE_CODE := v_SALESREP.SITE_CODE;
                   END IF;
                EXCEPTION
                   WHEN NO_DATA_FOUND
                   THEN
                      IF c_account_det%ISOPEN
                      THEN
                         CLOSE c_account_det;
                      END IF;

                      LB_VALID := FALSE;
                      LC_ERR_MSG :=
                            LC_ERR_MSG
                         || '. '
                         || 'SITE_CODE '
                         || v_SALESREP.SITE_CODE
                         || ' does not exist .';
                      debug_log (LC_ERR_MSG);
                   WHEN OTHERS
                   THEN
                      IF c_account_det%ISOPEN
                      THEN
                         CLOSE c_account_det;
                      END IF;

                      -- ln_item_id:=NULL;
                      LB_VALID := FALSE;
                      LC_ERR_MSG :=
                            LC_ERR_MSG
                         || '. '
                         || 'Other Exception while validating SITE_CODE: '
                         || v_SALESREP.SITE_CODE
                         || '-->'
                         || SQLERRM
                         || '.';
                      debug_log (LC_ERR_MSG);
                END;
             ELSE
                BEGIN
                   SELECT DISTINCT hcsu.site_use_id site_use_id
                     INTO ln_site_id
                     FROM hz_cust_accounts_all hca,
                          hz_cust_acct_sites_all hcas,
                          hz_cust_site_uses_all hcsu
                    WHERE     hca.cust_account_id = LN_CUST_ACCT_ID
                          AND hca.cust_account_id = hcas.cust_account_id
                          AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                          AND hcsu.site_use_code = v_SALESREP.SITE_CODE
                          AND hcas.org_id = ln_org_id
                          AND hcsu.primary_flag = 'Y';
                EXCEPTION
                   WHEN NO_DATA_FOUND
                   THEN
                      LB_VALID := FALSE;
                      LC_ERR_MSG :=
                            LC_ERR_MSG
                         || '. '
                         || 'site   '
                         || v_SALESREP.SITE_CODE
                         || '. '
                         || 'location   '
                         || v_SALESREP.SITE_location
                         || ' doesnot not exists for account '
                         || LN_CUST_ACCT_ID;
                      debug_log (LC_ERR_MSG);
                   WHEN OTHERS
                   THEN
                      LB_VALID := FALSE;
                      LC_ERR_MSG :=
                            LC_ERR_MSG
                         || '. '
                         || 'Other Exception while validating SITE_CODE: '
                         || v_SALESREP.SITE_CODE
                         || '-->'
                         || SQLERRM
                         || '.';
                      debug_log (LC_ERR_MSG);
                END;

                IF ln_site_id IS NOT NULL
                THEN
                   v_SALESREP.x_SITE_USE_ID := ln_site_id;
                   v_SALESREP.x_CUSTOMER_SITE := v_SALESREP.SITE_location;
                   v_SALESREP.x_SITE_USE_CODE := v_SALESREP.SITE_CODE;
                END IF;
             END IF;*/

            /* =================================================================================================================================
          Validation for SALES_REP
          =================================================================================================================================== */
            IF v_SALESREP.SALESREP_NAME IS NOT NULL
            THEN
                BEGIN
                    OPEN c_sales_rep_det (UPPER (v_SALESREP.SALESREP_NAME),
                                          Ln_ORG_ID);

                    FETCH c_sales_rep_det INTO LN_SALES_REP_id, LC_SALES_REP_NUM;

                    CLOSE c_sales_rep_det;

                    debug_log ('LN_SALES_REP_id: ' || LN_SALES_REP_id);
                    debug_log ('LC_SALES_REP_NUM: ' || LC_SALES_REP_NUM);
                    debug_log (
                        'v_SALESREP.SALESREP_NAME: ' || v_SALESREP.SALESREP_NAME);

                    IF LN_SALES_REP_ID IS NULL OR LN_SALES_REP_ID = 0
                    THEN
                        LB_VALID   := FALSE;
                        LC_ERR_MSG   :=
                               LC_ERR_MSG
                            || '. '
                            || 'SALES_REP  '
                            || v_SALESREP.SALESREP_NAME
                            || ' does not exists in jtf_rs_salesreps table .';
                        debug_log ('LC_ERR_MSG: ' || LC_ERR_MSG);
                    END IF;


                    v_SALESREP.x_SALESREP_ID       := LN_SALES_REP_id;
                    v_SALESREP.x_SALESREP_NUMBER   := LC_SALES_REP_NUM;
                    v_SALESREP.x_SALESREP_NAME     :=
                        v_SALESREP.SALESREP_NAME;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        --fnd_file.put_line (fnd_file.LOG, 'Test34');

                        IF c_sales_rep_det%ISOPEN
                        THEN
                            CLOSE c_sales_rep_det;
                        END IF;

                        LB_VALID   := FALSE;
                        LC_ERR_MSG   :=
                               LC_ERR_MSG
                            || '. '
                            || 'SALES_REP '
                            || v_SALESREP.SALESREP_NAME
                            || ' does not exist .';
                        debug_log (LC_ERR_MSG);
                    WHEN OTHERS
                    THEN
                        IF c_sales_rep_det%ISOPEN
                        THEN
                            CLOSE c_sales_rep_det;
                        END IF;

                        -- ln_item_id:=NULL;
                        LB_VALID   := FALSE;
                        LC_ERR_MSG   :=
                               LC_ERR_MSG
                            || '. '
                            || 'Other Exception while validating SALES_REP: '
                            || v_SALESREP.SALESREP_NAME
                            || '-->'
                            || SQLERRM
                            || '.';
                        debug_log (LC_ERR_MSG);
                END;
            END IF;



            /* =================================================================================================================================
            Validation for division,department,master_class and sub_class
            =================================================================================================================================== */
            debug_log ('v_SALESREP.SUB_CLASS: ' || v_SALESREP.SUB_CLASS);
            debug_log ('v_SALESREP.CLASS: ' || v_SALESREP.CLASS);
            debug_log ('v_SALESREP.DIVISION: ' || v_SALESREP.DIVISION);
            debug_log ('v_SALESREP.DEPARTMENT: ' || v_SALESREP.DEPARTMENT);

            IF     v_SALESREP.DIVISION IS NULL
               AND v_SALESREP.DEPARTMENT IS NULL
               AND v_SALESREP.CLASS IS NULL
               AND v_SALESREP.SUB_CLASS IS NULL
            THEN
                NULL;
            ELSIF     v_SALESREP.DIVISION IS NOT NULL
                  AND v_SALESREP.DEPARTMENT IS NULL
                  AND v_SALESREP.CLASS IS NULL
                  AND v_SALESREP.SUB_CLASS IS NULL
            THEN
                v_SALESREP.x_DIVISION   := v_SALESREP.DIVISION;
            ELSIF     v_SALESREP.DIVISION IS NOT NULL
                  AND v_SALESREP.DEPARTMENT IS NOT NULL
                  AND v_SALESREP.CLASS IS NULL
                  AND v_SALESREP.SUB_CLASS IS NULL
            THEN
                v_SALESREP.x_DIVISION     := v_SALESREP.DIVISION;
                v_SALESREP.x_DEPARTMENT   := v_SALESREP.DEPARTMENT;
            ELSIF     v_SALESREP.DIVISION IS NOT NULL
                  AND v_SALESREP.DEPARTMENT IS NOT NULL
                  AND v_SALESREP.CLASS IS NOT NULL
                  AND v_SALESREP.SUB_CLASS IS NULL
            THEN
                v_SALESREP.x_DIVISION     := v_SALESREP.DIVISION;
                v_SALESREP.x_DEPARTMENT   := v_SALESREP.DEPARTMENT;
                v_SALESREP.x_CLASS        := v_SALESREP.CLASS;
            ELSIF     v_SALESREP.DIVISION IS NOT NULL
                  AND v_SALESREP.DEPARTMENT IS NOT NULL
                  AND v_SALESREP.CLASS IS NOT NULL
                  AND v_SALESREP.SUB_CLASS IS NOT NULL
            THEN
                v_SALESREP.x_DIVISION     := v_SALESREP.DIVISION;
                v_SALESREP.x_DEPARTMENT   := v_SALESREP.DEPARTMENT;
                v_SALESREP.x_CLASS        := v_SALESREP.CLASS;
                v_SALESREP.x_DIVISION     := v_SALESREP.DIVISION;
            ELSE
                --fnd_file.put_line (fnd_file.LOG, 'Test35');
                LB_VALID   := FALSE;
                LC_ERR_MSG   :=
                       LC_ERR_MSG
                    || '. '
                    || 'DIVISION  '
                    || v_SALESREP.DIVISION
                    || '. '
                    || 'DEPARTMENT  '
                    || v_SALESREP.DEPARTMENT
                    || '. '
                    || 'MASTER_CLASS  '
                    || v_SALESREP.CLASS
                    || '. '
                    || 'SUB_CLASS  '
                    || v_SALESREP.SUB_CLASS
                    || ' doesnot not exists in EBS .';
            END IF;


            /* IF v_SALESREP.DEPARTMENT != null or v_SALESREP.DIVISION != null or v_SALESREP.CLASS != null or v_SALESREP.SUB_CLASS != NULL
             THEN
                BEGIN
                   SELECT COUNT (1)
      INTO LN_DIVISION
      FROM mtl_category_sets mcs, mtl_categories mc
     WHERE     mc.enabled_flag = 'Y'
           AND mc.structure_id = mcs.structure_id
           AND mcs.category_set_name = 'Inventory'
           AND UPPER (NVL (MC.SEGMENT1, ' ')) =
                  UPPER (NVL (v_SALESREP.brand, NVL (MC.SEGMENT1, ' ')))
           AND UPPER (NVL (MC.SEGMENT2, ' ')) =
                  UPPER (NVL (v_SALESREP.DIVISION, NVL (MC.SEGMENT2, ' ')))
           AND UPPER (NVL (MC.SEGMENT3, ' ')) =
                  UPPER (NVL (v_SALESREP.DEPARTMENT, NVL (MC.SEGMENT3, ' ')))
           AND UPPER (NVL (MC.SEGMENT4, ' ')) =
                         UPPER (NVL (v_SALESREP.CLASS, NVL (MC.SEGMENT4, ' ')))
           AND UPPER (NVL (MC.SEGMENT5, ' ') ) = UPPER (
                                                    NVL (v_SALESREP.SUB_CLASS,
                                                         NVL (MC.SEGMENT5, ' ')));
                   IF LN_DIVISION = 0
                   THEN
                      LB_VALID := FALSE;
                      LC_ERR_MSG :=
                            LC_ERR_MSG
                         || '. '
                         || 'DIVISION  '
                         || v_SALESREP.DIVISION
                         || '. '
                         || 'DEPARTMENT  '
                         || v_SALESREP.DEPARTMENT
                         || '. '
                         || 'MASTER_CLASS  '
                         || v_SALESREP.CLASS
                         || '. '
                         || 'SUB_CLASS  '
                         || v_SALESREP.SUB_CLASS
                         || ' doesnot not exists in EBS .';
                      debug_log ('LC_ERR_MSG : ' || LC_ERR_MSG);
                   ELSE
                      v_SALESREP.x_DIVISION := v_SALESREP.DIVISION;
                      v_SALESREP.x_DEPARTMENT := v_SALESREP.DEPARTMENT;
                      v_SALESREP.x_CLASS := v_SALESREP.CLASS;
                      v_SALESREP.x_SUB_CLASS := v_SALESREP.SUB_CLASS;

                   END IF;
                EXCEPTION
                   WHEN NO_DATA_FOUND
                   THEN
                      LB_VALID := FALSE;
                      LC_ERR_MSG :=
                            LC_ERR_MSG
                         || '. '
                         || 'DIVISION '
                         || v_SALESREP.DIVISION
                         || ' does not exist .';
                      debug_log (LC_ERR_MSG);
                   WHEN OTHERS
                   THEN
                      LB_VALID := FALSE;
                      LC_ERR_MSG :=
                            LC_ERR_MSG
                         || '. '
                         || 'Other Exception while validating DIVISION: '
                         || v_SALESREP.DIVISION
                         || '-->'
                         || SQLERRM
                         || '.';
                      debug_log (LC_ERR_MSG);
                END;
             END IF;*/


            IF NOT LB_VALID
            THEN
                UPDATE_SALESREP (
                    X_ERRBUF            => LC_ERRBUF,
                    X_RETCODE           => LN_RETCODE,
                    P_SATUS             => GC_STATUS_ERROR,
                    P_ERR_MSG           => LC_ERR_MSG,
                    P_RECORD_NO         => v_SALESREP.RECORD_NUMBER,
                    P_SUB_CLASS         => v_SALESREP.SUB_CLASS,
                    P_SITE_USE_ID       => v_SALESREP.x_SITE_USE_ID,
                    P_SITE_USE_CODE     => v_SALESREP.x_SITE_USE_CODE,
                    P_SALESREP_NUMBER   => v_SALESREP.x_SALESREP_NUMBER,
                    P_SALESREP_NAME     => v_SALESREP.x_SALESREP_NAME,
                    P_SALESREP_ID       => v_SALESREP.x_SALESREP_ID,
                    P_OU_NAME           => v_SALESREP.x_OU_NAME,
                    P_ORG_ID            => v_SALESREP.x_Org_id,
                    P_DIVISION          => v_SALESREP.x_DIVISION,
                    P_DEPARTMENT        => v_SALESREP.x_DEPARTMENT,
                    P_CUSTOMER_SITE     => v_SALESREP.x_CUSTOMER_SITE,
                    P_CUSTOMER_NUMBER   => v_SALESREP.x_CUSTOMER_NUMBER,
                    P_CUSTOMER_NAME     => v_SALESREP.CUSTOMER_NAME,
                    P_CUSTOMER_ID       => v_SALESREP.x_customer_id,
                    P_CLASS             => v_SALESREP.x_CLASS,
                    P_BRAND             => v_SALESREP.x_brand,
                    P_ACCOUNT_NAME      => v_SALESREP.x_account_name);
            ELSE
                UPDATE_SALESREP (
                    X_ERRBUF            => LC_ERRBUF,
                    X_RETCODE           => LN_RETCODE,
                    P_SATUS             => GC_STATUS_VAL,
                    P_RECORD_NO         => v_SALESREP.RECORD_NUMBER,
                    P_SUB_CLASS         => v_SALESREP.SUB_CLASS,
                    P_SITE_USE_ID       => v_SALESREP.x_SITE_USE_ID,
                    P_SITE_USE_CODE     => v_SALESREP.x_SITE_USE_CODE,
                    P_SALESREP_NUMBER   => v_SALESREP.x_SALESREP_NUMBER,
                    P_SALESREP_NAME     => v_SALESREP.x_SALESREP_NAME,
                    P_SALESREP_ID       => v_SALESREP.x_SALESREP_ID,
                    P_OU_NAME           => v_SALESREP.x_OU_NAME,
                    P_ORG_ID            => v_SALESREP.x_Org_id,
                    P_DIVISION          => v_SALESREP.x_DIVISION,
                    P_DEPARTMENT        => v_SALESREP.x_DEPARTMENT,
                    P_CUSTOMER_SITE     => v_SALESREP.x_CUSTOMER_SITE,
                    P_CUSTOMER_NUMBER   => v_SALESREP.x_CUSTOMER_NUMBER,
                    P_CUSTOMER_NAME     => v_SALESREP.CUSTOMER_NAME,
                    P_CUSTOMER_ID       => v_SALESREP.x_customer_id,
                    P_CLASS             => v_SALESREP.x_CLASS,
                    P_BRAND             => v_SALESREP.x_brand,
                    P_ACCOUNT_NAME      => v_SALESREP.x_account_name);

                SELECT STATUS
                  INTO lc_STATUS
                  FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
                 WHERE RECORD_NUMBER = v_SALESREP.RECORD_NUMBER;

                fnd_file.put_line (fnd_file.LOG,
                                   'lc_STATUS out ' || lc_STATUS);
            END IF;


            ln_counter             := ln_counter + 1;
        END LOOP;



        SELECT COUNT (*)
          INTO gn_salesreo_tot_rec
          FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST;

        SELECT COUNT (*)
          INTO gn_salesrep_val_rec
          FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
         WHERE STATUS = GC_STATUS_VAL;

        SELECT COUNT (*)
          INTO gn_salesrep_err_rec
          FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
         WHERE STATUS = GC_STATUS_ERROR;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF c_org_id%ISOPEN
            THEN
                CLOSE c_org_id;
            END IF;

            IF c_bill_to_site_det%ISOPEN
            THEN
                CLOSE c_bill_to_site_det;
            END IF;

            IF c_ship_to_site_det%ISOPEN
            THEN
                CLOSE c_ship_to_site_det;
            END IF;

            IF c_sales_rep_det%ISOPEN
            THEN
                CLOSE c_sales_rep_det;
            END IF;

            IF c_account_det%ISOPEN
            THEN
                CLOSE c_account_det;
            END IF;

            X_retcode   := gn_error;
            DEBUG_LOG ('Other Exception in the program VALIDATE_SALESREP');
    END VALIDATE_SALESREP;

    /*-******************************************************************************************************************************
    start of insert
    *********************************************************************************************************************************/

    PROCEDURE INSERT_SO (X_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        LC_ERRBUF    VARCHAR2 (1000) := NULL;
        LN_RETCODE   NUMBER := 0;


        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        --fnd_file.put_line (fnd_file.LOG, 'Test41');

        FOR v_salesrep_insert IN (SELECT *
                                    FROM XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST
                                   WHERE STATUS = GC_STATUS_VAL)
        LOOP
            BEGIN
                --fnd_file.put_line (fnd_file.LOG, 'Test42');

                INSERT INTO DO_CUSTOM.DO_REP_CUST_ASSIGNMENT
                         VALUES (v_salesrep_insert.x_customer_id,
                                 v_salesrep_insert.x_SALESREP_ID,
                                 v_salesrep_insert.x_SALESREP_NUMBER,
                                 v_salesrep_insert.x_SALESREP_NAME,
                                 v_salesrep_insert.x_brand,
                                 v_salesrep_insert.x_SITE_USE_ID,
                                 v_salesrep_insert.x_DIVISION,
                                 v_salesrep_insert.x_DEPARTMENT,
                                 v_salesrep_insert.x_CLASS,
                                 v_salesrep_insert.SUB_CLASS,
                                 APPS.FND_GLOBAL.USER_ID,
                                 v_salesrep_insert.x_Org_id,
                                 SYSDATE,
                                 APPS.FND_GLOBAL.USER_ID,
                                 SYSDATE,
                                 -1,
                                 v_salesrep_insert.x_OU_NAME,
                                 v_salesrep_insert.CUSTOMER_NAME,
                                 v_salesrep_insert.x_CUSTOMER_NUMBER,
                                 v_salesrep_insert.x_CUSTOMER_SITE,
                                 v_salesrep_insert.x_SITE_USE_CODE,
                                 v_salesrep_insert.x_account_name,
                                 SYSDATE,
                                 NULL);

                --fnd_file.put_line (fnd_file.LOG, 'Test43');

                UPDATE_SALESREP (
                    X_ERRBUF      => LC_ERRBUF,
                    X_RETCODE     => LN_RETCODE,
                    P_SATUS       => 'C',
                    P_RECORD_NO   => v_salesrep_insert.RECORD_NUMBER);

                --fnd_file.put_line (fnd_file.LOG, 'Test44');
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    UPDATE_SALESREP (
                        X_ERRBUF      => LC_ERRBUF,
                        X_RETCODE     => LN_RETCODE,
                        P_SATUS       => 'E',
                        P_ERR_MSG     => SQLERRM,
                        P_RECORD_NO   => v_salesrep_insert.RECORD_NUMBER);
            END;
        END LOOP;
    END INSERT_SO;

    PROCEDURE MAIN (X_ERRBUF OUT VARCHAR2, X_RETCODE OUT NUMBER)
    IS
    BEGIN
        xxdo_srep_update_Site_use_id;

        VALIDATE_SALESREP (X_ERRBUF, X_RETCODE);

        INSERT_SO (X_ERRBUF, X_RETCODE);


        UPDATE XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST st
           SET STATUS   = 'AC'
         WHERE status = 'NEW';

        --fnd_file.put_line (fnd_file.LOG, 'Test5');
        PRINT_OUT ('Table  :XXDO.XXD_DEFAULT_SALESREP_MATRIX_ST');
        PRINT_OUT ('-----------------------------------------------------');
        PRINT_OUT ('  ');
        PRINT_OUT ('No.Of Records Read            :' || gn_salesreo_tot_rec);
        PRINT_OUT ('No. Of Records Valiadted      :' || gn_salesrep_val_rec);
        PRINT_OUT ('No. Of Records Errored        :' || gn_salesrep_err_rec);
        PRINT_OUT ('  ');
        PRINT_OUT ('-----------------------------------------------------');
    END MAIN;
END XXDO_SALESREP_PKG1;
/
