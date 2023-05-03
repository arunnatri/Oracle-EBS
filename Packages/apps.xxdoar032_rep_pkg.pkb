--
-- XXDOAR032_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDOAR032_REP_PKG
AS
    /******************************************************************************
       NAME: XXDOAR032_REP_PKG
       REP NAME:AP Parked Invoices - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       05/31/2013     Shibu        1. Created this package for XXDOAR032_REP_PKG Report
       V1.1     28-APR-2015  BT Technology Team   Retrofit for BT project
    ******************************************************************************/

    PROCEDURE collector_upd (PV_ERRBUF OUT VARCHAR2, PV_RETCODE OUT VARCHAR2, PN_FRM_COLL_ID NUMBER
                             , PN_TO_COLL_ID NUMBER)
    IS
        CURSOR C_MAIN (PN_TO_COLL_ID NUMBER)
        IS
            SELECT party.party_name, cust.account_number, col.name,
                   usr.user_name Last_Updated_User, cust_prof.LAST_UPDATE_DATE
              FROM apps.hz_cust_accounts cust, apps.hz_parties party, apps.hz_customer_profiles cust_prof,
                   apps.ar_collectors col, apps.fnd_user usr
             WHERE     cust.party_id = party.party_id
                   AND cust.cust_account_id = cust_prof.CUST_ACCOUNT_ID
                   AND cust_prof.SITE_USE_ID IS NULL
                   AND cust_prof.COLLECTOR_ID = col.COLLECTOR_ID
                   AND col.COLLECTOR_ID = PN_TO_COLL_ID
                   AND cust_prof.LAST_UPDATED_BY = usr.user_id;

        lv_detils   VARCHAR2 (32000);
    BEGIN
        --Update Starts
        BEGIN
            apps.FND_FILE.PUT_LINE (apps.FND_FILE.LOG,
                                    '----Update Starts----');

            UPDATE apps.hz_customer_profiles
               SET COLLECTOR_ID = PN_TO_COLL_ID, LAST_UPDATED_BY = apps.fnd_profile.VALUE ('USER_ID'), LAST_UPDATE_DATE = SYSDATE
             WHERE SITE_USE_ID IS NULL AND COLLECTOR_ID = PN_FRM_COLL_ID;

            apps.FND_FILE.PUT_LINE (
                apps.FND_FILE.LOG,
                'Updated ' || SQL%ROWCOUNT || ' Records.');

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
        END;

        --Update Ends



        -- Set Header Line

        lv_detils   :=
               'Party Name'
            || CHR (9)
            || 'Account Number'
            || CHR (9)
            || 'New Collector Name'
            || CHR (9)
            || 'Last Updated User'
            || CHR (9)
            || 'Last Updated Date';

        apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT, lv_detils);

        FOR i IN C_MAIN (PN_TO_COLL_ID)
        LOOP
            -- Set Detail Line

            lv_detils   :=
                   i.party_name
                || CHR (9)
                || i.account_number
                || CHR (9)
                || i.name
                || CHR (9)
                || i.Last_Updated_User
                || CHR (9)
                || i.LAST_UPDATE_DATE;
            -- Write Detail Line
            apps.FND_FILE.PUT_LINE (apps.FND_FILE.OUTPUT, lv_detils);
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'NO_DATA_FOUND');
            PV_ERRBUF    := 'No Data Found' || SQLCODE || SQLERRM;
            PV_RETCODE   := -1;
        WHEN INVALID_CURSOR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'INVALID_CURSOR');
            PV_ERRBUF    := 'Invalid Cursor' || SQLCODE || SQLERRM;
            PV_RETCODE   := -2;
        WHEN TOO_MANY_ROWS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'TOO_MANY_ROWS');
            PV_ERRBUF    := 'Too Many Rows' || SQLCODE || SQLERRM;
            PV_RETCODE   := -3;
        WHEN PROGRAM_ERROR
        THEN
            --    DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'PROGRAM_ERROR');
            PV_ERRBUF    := 'Program Error' || SQLCODE || SQLERRM;
            PV_RETCODE   := -4;
        WHEN OTHERS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Program Terminated Abruptly');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'All Data is Not Processed');
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'OTHERS');
            PV_ERRBUF    := 'Unhandled Error' || SQLCODE || SQLERRM;
            PV_RETCODE   := -5;
    END collector_upd;
END XXDOAR032_REP_PKG;
/
