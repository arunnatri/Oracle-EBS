--
-- XXDO_INT_010_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdo_int_010_pkg
IS
    PROCEDURE xxdo_int_010_rcv (errfbuf          OUT VARCHAR2,
                                retcode          OUT VARCHAR2,
                                p_so_number   IN     NUMBER);

    PROCEDURE xxdo_int_010_prc (p_dc_dest_id IN NUMBER, p_distro_doc_type IN VARCHAR2, p_item_id IN NUMBER, p_unit_qty IN NUMBER, p_receipt_type IN VARCHAR2, p_receipt_nbr IN VARCHAR2
                                , p_asn_nbr IN VARCHAR2, p_po_nbr IN VARCHAR2, p_cnt_qty IN VARCHAR2);
END;
/
