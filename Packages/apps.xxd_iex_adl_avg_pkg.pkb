--
-- XXD_IEX_ADL_AVG_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_IEX_ADL_AVG_PKG
IS
    PROCEDURE LOG (pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF fnd_global.conc_login_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
        END IF;
    END LOG;

    -- +---------------------------------------------+
    -- | Procedure to print messages or notes in the |
    -- | OUTPUT file of the concurrent program       |
    -- +---------------------------------------------+

    PROCEDURE output (pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF fnd_global.conc_login_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.output, pv_msgtxt_in);
        END IF;
    END output;



    PROCEDURE prc_get_AVG_ADL_cust (pn_cust_id NUMBER, Pv_column_name VARCHAR2, xn_qtr_avg OUT NUMBER)
    IS
        lv_sql_stmt   VARCHAR2 (1000);
        ln_avg_adl    NUMBER (15, 2);
    BEGIN
        lv_sql_stmt   :=
               'select sum(nvl('
            || Pv_column_name
            || ',0))/count(1)
from xxd_iex_metrics_tbl
 where cust_account_id in(
select cust_account_id from hz_customer_profiles where party_id = '
            || pn_cust_id
            || ')
and '
            || Pv_column_name
            || ' is not null';


        EXECUTE IMMEDIATE lv_sql_stmt
            INTO ln_avg_adl;

        xn_qtr_avg   := ln_avg_adl;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                   'Error found while calculating quarterly Avgerages @ XXD_IEX_ADL_AVG_PKG.prc_get_AVG_ADL'
                || SQLERRM);
    END;
END;
/
