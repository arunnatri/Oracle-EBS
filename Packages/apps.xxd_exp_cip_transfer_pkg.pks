--
-- XXD_EXP_CIP_TRANSFER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_EXP_CIP_TRANSFER_PKG
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
        RETURN NUMBER;

    FUNCTION INSERT_TABLE (p_transfer_ref_no VARCHAR2)
        RETURN NUMBER;

    FUNCTION CHECK_PROCESS_INIT (p_transfer_ref_no VARCHAR2)
        RETURN VARCHAR2;
END XXD_EXP_CIP_TRANSFER_PKG;
/


GRANT EXECUTE ON APPS.XXD_EXP_CIP_TRANSFER_PKG TO XXDO
/
