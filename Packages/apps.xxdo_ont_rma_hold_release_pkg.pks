--
-- XXDO_ONT_RMA_HOLD_RELEASE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ONT_RMA_HOLD_RELEASE_PKG"
AS
    PROCEDURE main (errbuf         OUT VARCHAR2,
                    retcode        OUT NUMBER,
                    p_rma_num   IN     VARCHAR2);
END;
/
