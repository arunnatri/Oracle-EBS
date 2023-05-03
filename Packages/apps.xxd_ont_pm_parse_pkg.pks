--
-- XXD_ONT_PM_PARSE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_PM_PARSE_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_PM_PARSE_PKG
    -- Design       : This package will be used to parse json data from UI
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 24-MAR-2021    Infosys              1.0    Initial Version

    -- #########################################################################################################################

    PROCEDURE fetch_batch_id (p_out_batch_id OUT NUMBER);

    PROCEDURE parse_data (p_input_data     IN     CLOB,
                          p_out_err_msg       OUT VARCHAR2,
                          p_out_batch_id      OUT NUMBER);
END XXD_ONT_PM_PARSE_PKG;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_PM_PARSE_PKG TO XXORDS
/
