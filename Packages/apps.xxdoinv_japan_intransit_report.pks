--
-- XXDOINV_JAPAN_INTRANSIT_REPORT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINV_JAPAN_INTRANSIT_REPORT"
AS
    /******************************************************************************************
    * Package          : xxdoinv_japan_intransit_report
    * Author           : BT Technology Team
    * Program Name     : In-Transit Inventory Report - Deckers
    *
    * Modification  :
    *----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *----------------------------------------------------------------------------------------------
    *    22-APRIL-2015 BT Technology Team     V1.1      Package being used for create journals in the GL.
    *   10-JUN-2015    BT Technology Team     V1.2     Fixed the HPQC Defect#2321
    ************************************************************************************************/

    PROCEDURE run_japan_intransit_report (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_inv_org_id IN NUMBER, p_region IN VARCHAR2, p_as_of_date IN VARCHAR2, p_cost_type_id IN NUMBER, p_brand IN VARCHAR2, p_show_color IN VARCHAR2, p_show_supplier_details IN VARCHAR2, p_markup_rate_type IN VARCHAR2, p_elimination_org IN VARCHAR2, p_elimination_rate IN VARCHAR2
                                          , p_dummy_elimination_rate IN VARCHAR2, p_user_rate IN NUMBER, p_debug_level IN NUMBER:= NULL);
END;
/
