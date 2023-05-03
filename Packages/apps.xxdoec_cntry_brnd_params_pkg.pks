--
-- XXDOEC_CNTRY_BRND_PARAMS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_CNTRY_BRND_PARAMS_PKG"
AS
    g_error   BOOLEAN := FALSE;

    TYPE t_param_detail_cursor IS REF CURSOR;

    PROCEDURE get_param_detail (o_param_detail OUT t_param_detail_cursor);
/**************************************************************************************
Country Brand Params call for use in DCD.Configuration
          Author:  Aram Malinich
           07-19-2012 - rkinsel -  added parms starting with "INV_" from inventory config
***************************************************************************************/
END XXDOEC_CNTRY_BRND_PARAMS_PKG;
/
