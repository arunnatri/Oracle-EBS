--
-- XXDOEC_PROCESS_CP_SHIPMENTS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_PROCESS_CP_SHIPMENTS"
AS
    PROCEDURE receive_po_lines (x_errbuf           OUT VARCHAR2,
                                x_retcode          OUT NUMBER,
                                p_shipment_id   IN     NUMBER);

    PROCEDURE pick_release_so_lines (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_shipment_id IN NUMBER);

    PROCEDURE ship_confirm_so_lines (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_shipment_id IN NUMBER);
END XXDOEC_PROCESS_CP_SHIPMENTS;
/
