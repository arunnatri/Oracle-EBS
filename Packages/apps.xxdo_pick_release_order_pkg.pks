--
-- XXDO_PICK_RELEASE_ORDER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PICK_RELEASE_ORDER_PKG"
AS
    PROCEDURE XXDO_PICK_RELEASE_FOR_ORDER (
        p_out_chr_ret_message         OUT NOCOPY VARCHAR2,
        p_out_num_ret_status          OUT NOCOPY NUMBER,
        p_req_id_str                  OUT NOCOPY VARCHAR2,
        p_user_id                  IN            NUMBER,
        p_resp_id                  IN            NUMBER,
        p_resp_appl_id             IN            NUMBER,
        p_order                                  NUMBER,
        p_min_line_pick_pct                      NUMBER,
        p_min_unit_pick_pct                      NUMBER,
        p_min_line_cnt_pick_pct                  NUMBER,
        p_min_line_unit_pick_pct                 NUMBER);
END XXDO_PICK_RELEASE_ORDER_PKG;
/
