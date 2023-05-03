--
-- XXDOPO_MOQ_SURCHARGE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOPO_MOQ_SURCHARGE_PKG"
IS
    /****************************************************************************************
    * Package      : XXDOPO_MOQ_SURCHARGE_PKG
    * Author       : BT Technology Team
    * Created      : 21-OCT-2014
    * Program Name : MOQ Surcharge Program - Deckers
    * Description  : Package used by: MOQ Surcharge Program - Deckers
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 09-SEP-2014   BT Technology Team  1.00       Retrofitted
    ****************************************************************************************/
    PROCEDURE xxdo_moq_surcharge_proc (err_buf    OUT VARCHAR2,
                                       ret_code   OUT NUMBER);
END xxdopo_moq_surcharge_pkg;
/
