--
-- XXD_EXP_CIP_TRANSFER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_EXP_CIP_TRANSFER_PKG
AS
    /*******************************************************************************
 * Program Name : XXD_EXP_CIP_TRANSFER_PKG
 * Language  : PL/SQL
 * Description  : This package will be used to do DDL/DML ON GT Tables
 * History :
 *
 *   WHO    Version  when   Desc
 * --------------------------------------------------------------------------
 * BT Technology Team   1.0    21/Jan/2015  Development
 * --------------------------------------------------------------------------- */

    FUNCTION TRUNC_TABLE
        RETURN NUMBER
    AS
        lv_count   NUMBER := 1;
    BEGIN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXD_EXP_CIP_TRANSFER_GT';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXD_EXP_CIP_TRANSFER_GT2';

        SELECT COUNT (*) INTO lv_count FROM XXDO.XXD_EXP_CIP_TRANSFER_GT;

        RETURN lv_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            SELECT COUNT (*) INTO lv_count FROM XXDO.XXD_EXP_CIP_TRANSFER_GT;

            RETURN lv_count;
    END TRUNC_TABLE;

    ------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION INSERT_TABLE (p_transfer_ref_no VARCHAR2)
        RETURN NUMBER
    AS
        lv_count          NUMBER := 1;
        lv_transfer_ref   VARCHAR2 (4000);
    BEGIN
        lv_transfer_ref   := p_transfer_ref_no;

        EXECUTE IMMEDIATE   'INSERT INTO XXDO.XXD_EXP_CIP_TRANSFER_GT (SELECT * FROM XXDO.XXD_EXP_CIP_TRANSFER WHERE '
                         || lv_transfer_ref
                         || ')';

        EXECUTE IMMEDIATE   'INSERT INTO XXDO.XXD_EXP_CIP_TRANSFER_GT2 (SELECT * FROM XXDO.XXD_EXP_CIP_TRANSFER WHERE '
                         || lv_transfer_ref
                         || ')';

        SELECT COUNT (*) INTO LV_COUNT FROM XXDO.XXD_EXP_CIP_TRANSFER_GT;

        RETURN lv_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            SELECT COUNT (*) INTO LV_COUNT FROM xxdo.xxd_exp_cip_transfer_gt;

            RETURN lv_count;
    END INSERT_TABLE;

    ------------------------------------------------------------------------------------------------------------------------------------

    FUNCTION CHECK_PROCESS_INIT (p_transfer_ref_no VARCHAR2)
        RETURN VARCHAR2
    AS
        -- To Check if there are any transfers in Status Draft/Error/Marked for Process. If exists it returns N

        lv_count          NUMBER := 1;
        lv_transfer_ref   VARCHAR2 (4000);
    BEGIN
        lv_transfer_ref   := p_transfer_ref_no;

        SELECT COUNT (*)
          INTO lv_count
          FROM XXDO.XXD_EXP_CIP_TRANSFER_GT
         WHERE     STATUS IN ('D', 'E', 'M')
               AND transfer_ref_no = lv_transfer_ref;

        IF lv_count > 0
        THEN
            RETURN 'N';
        ELSE
            RETURN 'Y';
        END IF;             -- To Disable/Enable the 'Process Transfer Button'
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END CHECK_PROCESS_INIT;
END XXD_EXP_CIP_TRANSFER_PKG;
/


GRANT EXECUTE ON APPS.XXD_EXP_CIP_TRANSFER_PKG TO XXDO
/
