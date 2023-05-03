--
-- XXDO_EDI_ANALYSIS_PK  (Package) 
--
/* Formatted on 4/26/2023 4:15:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_EDI_ANALYSIS_PK"
AS
    PROCEDURE analyse_edi_inbound;
END XXDO_EDI_ANALYSIS_PK;
/


GRANT EXECUTE ON APPS.XXDO_EDI_ANALYSIS_PK TO SOA_INT
/

GRANT EXECUTE ON APPS.XXDO_EDI_ANALYSIS_PK TO XXDO
/
