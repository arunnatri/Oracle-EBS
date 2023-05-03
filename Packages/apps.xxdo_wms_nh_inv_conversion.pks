--
-- XXDO_WMS_NH_INV_CONVERSION  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_WMS_NH_INV_CONVERSION"
AS
    /******************************************************************************************
    -- Modification History:
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 18-MAR-2018  1.0        Krishna Lavu            NH Inventory Movement Project

    ******************************************************************************************/

    TYPE order_record IS RECORD
    (
        order_number    VARCHAR2 (100)
    );

    TYPE order_table IS TABLE OF order_record;

    PROCEDURE insert_message (pv_message_type   IN VARCHAR2,
                              pv_message        IN VARCHAR2);

    PROCEDURE extract_main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_brand IN VARCHAR2, pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2, pv_dock_door IN VARCHAR2, pn_dest_org_id IN NUMBER, pv_dest_subinv IN VARCHAR2
                            , pv_dest_locator IN VARCHAR2);

    FUNCTION validate_data (pv_brand         IN VARCHAR2,
                            pn_src_org_id    IN NUMBER,
                            pv_src_subinv    IN VARCHAR2,
                            pv_src_locator   IN VARCHAR2,
                            pn_dest_org_id   IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE onhand_insert (pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2, pn_dest_org_id IN NUMBER, pv_dest_subinv IN VARCHAR2, pv_dest_locator IN VARCHAR2
                             , pv_return_status OUT VARCHAR2);

    PROCEDURE onhand_extract (pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2);

    PROCEDURE create_internal_requisition (pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2, pn_dest_org_id IN NUMBER, pv_dest_subinv IN VARCHAR2, pv_dest_locator IN VARCHAR2
                                           , pv_return_status OUT VARCHAR2);

    PROCEDURE pick_release_iso (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_org IN VARCHAR2, pv_iso_num IN VARCHAR2, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2
                                , pv_dock_door IN VARCHAR2);

    PROCEDURE pick_confirm_order (pv_iso_num IN VARCHAR2, pn_org_id IN NUMBER, pv_dock_door IN VARCHAR2
                                  , pv_return_status OUT VARCHAR2);

    PROCEDURE drop_loaded_lpn (pv_dock_door         IN     VARCHAR2,
                               pn_organization_id   IN     NUMBER,
                               pv_lpn               IN     VARCHAR2,
                               x_ret_stat              OUT VARCHAR2,
                               x_message               OUT VARCHAR2);

    PROCEDURE drop_lpn (pn_organization_id     IN            NUMBER,
                        pn_lpn_id              IN            NUMBER,
                        pn_inventory_item_id   IN            NUMBER,
                        pv_subinventory_code   IN            VARCHAR2,
                        pn_locator             IN            NUMBER,
                        x_ret_stat                OUT        VARCHAR2,
                        x_msg_count               OUT NOCOPY NUMBER,
                        x_msg_data                OUT NOCOPY VARCHAR2);

    FUNCTION get_transaction_date (pn_item_id   IN NUMBER,
                                   pn_org_id    IN NUMBER,
                                   pn_qty       IN NUMBER)
        RETURN DATE;

    FUNCTION f_get_onhand (pn_item_id IN NUMBER, pn_org_id IN NUMBER, pv_sub IN VARCHAR2
                           , pn_locator_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE insert_iso_data (pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2);

    PROCEDURE relieve_atp;

    PROCEDURE create_internal_orders (pv_return_status OUT VARCHAR2);

    PROCEDURE run_order_import (pv_return_status OUT VARCHAR2);

    PROCEDURE schedule_iso;

    FUNCTION f_get_supply (pn_item_id IN NUMBER, pn_org_id IN NUMBER, pn_start_date IN DATE
                           , pn_end_date IN DATE)
        RETURN NUMBER;

    PROCEDURE nh_inventory_report (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, pv_brand VARCHAR2, pv_src_org NUMBER, pv_dest_org NUMBER, pn_first_n_days NUMBER
                                   , pn_second_n_days NUMBER);

    PROCEDURE pick_release_main (pv_errbuf    OUT VARCHAR2,
                                 pv_retcode   OUT VARCHAR2);

    PROCEDURE update_location_status (pn_src_org_id IN NUMBER, pv_src_locator IN VARCHAR2, pn_locator_status IN NUMBER);

    /* CCR0007600 New program to validate Truck Location */
    PROCEDURE validate_locator (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_brand IN VARCHAR2, pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2, pv_dock_door IN VARCHAR2, pn_dest_org_id IN NUMBER, pv_dest_subinv IN VARCHAR2
                                , pv_dest_locator IN VARCHAR2);
END XXDO_WMS_NH_INV_CONVERSION;
/
