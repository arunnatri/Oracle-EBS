--
-- XXD_UPDATE_PO_FACT_FINISH_DATE  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_UPDATE_PO_FACT_FINISH_DATE"
IS
    /****************************************************************************************
    * Package      : XXD_UPDATE_PO_FACT_FINISH_DATE
    * Author       : BT Technology Team
    * Created      : 21-OCT-2014
    * Program Name : Deckers - PO Factory Finish Date Update Program
    * Description  : Package used by: Deckers - PO Factory Finish Date Update Program
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 20-JUL-2015   BT Technology Team  1.00       Created
    ****************************************************************************************/
    PROCEDURE xxd_update_fact_finish_date (err_buf    OUT VARCHAR2,
                                           ret_code   OUT NUMBER);
END XXD_UPDATE_PO_FACT_FINISH_DATE;
/
