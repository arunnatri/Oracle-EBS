--
-- XXDOPO_AUTO_INTRANSIT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOPO_AUTO_INTRANSIT"
/*
================================================================
 Created By              : BT Technology Team
 Creation Date           : 14-April-2015
 File Name               : XXDOPO_AUTO_INTRANSIT.pks
 Incident Num            :
 Description             :
 Latest Version          : 1.0

================================================================
 Date               Version#    Name                    Remarks
================================================================
14-April-2015        1.0       BT Technology Team
07-Feb-2018          1.1       CCR0006936
22-May-2019          1.2       Aravind Kannuri          CCR0007955
23-AUG-2021          2.0       Srinath Siricilla        CCR0009441
29-APR-2022          2.1       Srinath Siricilla        CCR0009984
This is an Deckers Purchasing Intransit Accrual program to create the Journals for ASN
======================================================================================
*/

AS
    FUNCTION get_amount (p_cost                  IN VARCHAR2,
                         p_organization_id       IN NUMBER,
                         p_inventory_item_id     IN NUMBER,
                         p_po_header_id          IN NUMBER,
                         p_po_line_id            IN NUMBER,
                         p_po_line_location_id   IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_ccid (p_segments IN VARCHAR2, p_coc_id IN NUMBER, --added as per CR#54
                                                                   p_organization_id IN NUMBER
                       , p_inventory_item_num IN NUMBER)
        RETURN NUMBER;

    PROCEDURE insert_into_gl_iface (p_ledger_id IN NUMBER, p_date_created IN DATE, p_currency_code IN VARCHAR2, p_code_combination_id IN NUMBER, p_debit_amount IN NUMBER, p_credit_amount IN NUMBER, p_batch_name IN VARCHAR2, p_batch_desc IN VARCHAR2, p_journal_name IN VARCHAR2, p_journal_desc IN VARCHAR2, p_line_desc IN VARCHAR2, p_context IN VARCHAR2
                                    , p_attribute1 IN VARCHAR2--                                   p_insert_into_gl        IN VARCHAR2 := 'Y' -- Added as per CCR0009441
                                                              -- Commented p_insert_into_gl as per CCRCCR0009984
                                                              );

    --START Added as per CCR0007955
    /* To determine the CCID Segments even CCID IS NULL */
    PROCEDURE get_ccid_segments (p_segments IN VARCHAR2, p_coc_id IN NUMBER, p_organization_id IN NUMBER, p_inventory_item_num IN NUMBER, p_segment1 OUT VARCHAR2, p_segment2 OUT VARCHAR2, p_segment3 OUT VARCHAR2, p_segment4 OUT VARCHAR2, p_segment5 OUT VARCHAR2, p_segment6 OUT VARCHAR2, p_segment7 OUT VARCHAR2, p_segment8 OUT VARCHAR2
                                 , p_ccid OUT NUMBER);

    /* Procedure to Insert without CCID into Interface Table */
    PROCEDURE insert_gl_iface_noccid (p_ledger_id       IN NUMBER,
                                      p_date_created    IN DATE,
                                      p_currency_code   IN VARCHAR2,
                                      -- p_code_combination_id   IN NUMBER,
                                      p_segment1        IN VARCHAR2,
                                      p_segment2        IN VARCHAR2,
                                      p_segment3        IN VARCHAR2,
                                      p_segment4        IN VARCHAR2,
                                      p_segment5        IN VARCHAR2,
                                      p_segment6        IN VARCHAR2,
                                      p_segment7        IN VARCHAR2,
                                      p_segment8        IN VARCHAR2,
                                      p_debit_amount    IN NUMBER,
                                      p_credit_amount   IN NUMBER,
                                      p_batch_name      IN VARCHAR2,
                                      p_batch_desc      IN VARCHAR2,
                                      p_journal_name    IN VARCHAR2,
                                      p_journal_desc    IN VARCHAR2,
                                      p_line_desc       IN VARCHAR2,
                                      p_context         IN VARCHAR2,
                                      p_attribute1      IN VARCHAR2--                                     p_insert_into_gl        IN VARCHAR2 := 'Y' -- Added as per CCR0009441
                                                                   -- Commented p_insert_into_gl as per CCRCCR0009984
                                                                   );

    --END Added as per CCR0007955


    PROCEDURE create_In_Transit (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_ou IN NUMBER
                                 , p_shipment_number IN VARCHAR2);

    PROCEDURE Create_In_Transit (psqlstat               OUT VARCHAR2,
                                 perrproc               OUT VARCHAR2,
                                 p_ou                IN     NUMBER, --added as per CR#54
                                 p_shipment_number   IN     VARCHAR2,
                                 p_cst_adj_only      IN     VARCHAR2); --Added for CCR0006936

    --Added for CCR0006936
    PROCEDURE create_adjustments_interface (
        psqlstat               OUT VARCHAR2,
        perrproc               OUT VARCHAR2,
        p_shipment_number   IN     VARCHAR2,
        p_ou                IN     NUMBER,
        p_region            IN     VARCHAR2);

    --End CCR0006936

    PROCEDURE create_cancel_interface (psqlstat               OUT VARCHAR2,
                                       perrproc               OUT VARCHAR2,
                                       p_shipment_number   IN     VARCHAR2,
                                       p_ou                IN     NUMBER,
                                       p_region            IN     VARCHAR2);

    PROCEDURE create_correction_interface (
        psqlstat               OUT VARCHAR2,
        perrproc               OUT VARCHAR2,
        p_shipment_number   IN     VARCHAR2,
        p_ou                IN     NUMBER,
        p_region            IN     VARCHAR2);

    -- Start of Change for CCR0009441

    -- Commented as per CCR0009984
    --   FUNCTION get_duty_valid_flag_fnc (pn_org_id   IN NUMBER,
    --          pv_element  IN VARCHAR2)
    --   RETURN VARCHAR2;
    -- Commented as per CCR0009984

    FUNCTION get_duty_valid_fnc (pn_org_id IN NUMBER, pv_element IN VARCHAR2)
        RETURN NUMBER;
-- End of Change for CCR0009441

END XXDOPO_AUTO_INTRANSIT;
/
