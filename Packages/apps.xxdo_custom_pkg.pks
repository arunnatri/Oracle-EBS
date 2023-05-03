--
-- XXDO_CUSTOM_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_CUSTOM_PKG"
AS
    PROCEDURE xxdo_custom_rcv_prc (pv_errbuff   OUT VARCHAR2,
                                   pv_retcode   OUT NUMBER);
END;
/
