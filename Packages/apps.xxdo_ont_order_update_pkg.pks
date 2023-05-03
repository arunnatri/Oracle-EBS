--
-- XXDO_ONT_ORDER_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   WSH_DELIVERY_DETAILS_PUB (Package)
--   UTL_SMTP (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ONT_ORDER_UPDATE_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_order_update.sql   1.0    2014/07/31   10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_order_update
    --
    -- Description  :  This is package  for WMS to OMS Ship Confirm Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 31-Jul-14    Infosys            1.0       Created
    -- 31-Dec-22    Shivanshu          2.6       Modified for CCR0010172
    -- ***************************************************************************

    --------------------------



    TYPE tabtype_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;


    TYPE delivery_txn IS RECORD
    (
        delivery_detail_id    NUMBER := 0,
        transaction_id        NUMBER := 0
    );

    TYPE Tab_del_txn IS TABLE OF delivery_txn
        INDEX BY BINARY_INTEGER;


    -------------------------
    g_num_api_version              NUMBER := 1.0;
    g_chr_status                   VARCHAR2 (100) := 'UNPROCESSED';
    g_num_user_id                  NUMBER := fnd_global.user_id;
    g_num_resp_id                  NUMBER := fnd_global.resp_id;
    g_num_resp_appl_id             NUMBER := fnd_global.resp_appl_id;
    g_num_login_id                 NUMBER := fnd_global.login_id;
    g_num_request_id               NUMBER := fnd_global.conc_request_id;
    g_num_prog_appl_id             NUMBER := fnd_global.prog_appl_id;
    g_dt_current_date              DATE := SYSDATE;
    g_chr_status_code              VARCHAR2 (1) := '0';
    g_chr_status_msg               VARCHAR2 (4000);
    g_ret_sts_warning              VARCHAR2 (1) := 'W';

    g_smtp_connection              UTL_SMTP.connection := NULL;
    g_num_connection_flag          NUMBER := 0;

    g_chr_order_status_prgm_name   VARCHAR2 (30) := 'XXDO_ORDER_STATUS';


    PROCEDURE main_validate (errbuf             OUT VARCHAR2,
                             retcode            OUT NUMBER,
                             p_wh_code       IN     VARCHAR2,
                             p_order_num     IN     VARCHAR2,
                             p_source        IN     VARCHAR2 DEFAULT 'WMS',
                             p_destination   IN     VARCHAR2 DEFAULT 'EBS',
                             p_purge_days    IN     NUMBER DEFAULT 30,
                             p_status        IN     VARCHAR2);

    PROCEDURE back_order (errbuf              OUT VARCHAR2,
                          retcode             OUT NUMBER,
                          p_order_number   IN     VARCHAR2);

    PROCEDURE pick_confirm (p_order_number   IN     VARCHAR2,
                            p_out_msg           OUT VARCHAR2);

    PROCEDURE pick_line (p_in_num_mo_line_id IN NUMBER, p_in_txn_hdr_id IN NUMBER, p_out_msg OUT VARCHAR2);

    PROCEDURE assign_detail_to_delivery (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_in_num_delivery_id IN NUMBER
                                         , p_in_chr_delivery_name IN VARCHAR2, p_in_delivery_detail_ids IN tabtype_id, p_in_chr_action IN VARCHAR2 DEFAULT 'ASSIGN');

    PROCEDURE update_backord_delivery (
        errbuf                    OUT VARCHAR2,
        retcode                   OUT NUMBER,
        p_in_num_delivery_id   IN     NUMBER,
        p_changed_attributes   IN     wsh_delivery_details_pub.changedattributetabtype);

    PROCEDURE clear_bucket (p_errbuf       OUT VARCHAR2,
                            p_retcode      OUT NUMBER,
                            del_txn_t   IN     Tab_del_txn);

    PROCEDURE insert_pick_data (p_wh_id            IN VARCHAR2,
                                p_order_num        IN VARCHAR2,
                                p_date             IN DATE,
                                p_status           IN VARCHAR2,
                                p_shipment_num     IN VARCHAR2,
                                p_ship_status      IN VARCHAR2,
                                p_cmt_load         IN VARCHAR2,
                                p_shipment_num1    IN VARCHAR2,
                                p_mst_load1        IN VARCHAR2,
                                p_cmt_ship1        IN VARCHAR2,
                                p_shipment_num2    IN VARCHAR2,
                                p_mst_load2        IN VARCHAR2,
                                p_cmt_ship2        IN VARCHAR2,
                                p_shipment_num3    IN VARCHAR2,
                                p_mst_load3        IN VARCHAR2,
                                p_cmt_ship3        IN VARCHAR2,
                                p_shipment_num4    IN VARCHAR2,
                                p_mst_load4        IN VARCHAR2,
                                p_cmt_ship4        IN VARCHAR2,
                                p_shipment_num5    IN VARCHAR2,
                                p_mst_load5        IN VARCHAR2,
                                p_cmt_ship5        IN VARCHAR2,
                                p_shipment_num6    IN VARCHAR2,
                                p_mst_load6        IN VARCHAR2,
                                p_cmt_ship6        IN VARCHAR2,
                                p_shipment_num7    IN VARCHAR2,
                                p_mst_load7        IN VARCHAR2,
                                p_cmt_ship7        IN VARCHAR2,
                                p_shipment_num8    IN VARCHAR2,
                                p_mst_load8        IN VARCHAR2,
                                p_cmt_ship8        IN VARCHAR2,
                                p_shipment_num9    IN VARCHAR2,
                                p_mst_load9        IN VARCHAR2,
                                p_cmt_ship9        IN VARCHAR2,
                                p_shipment_num10   IN VARCHAR2,
                                p_mst_load10       IN VARCHAR2,
                                p_cmt_ship10       IN VARCHAR2,
                                p_message_id       IN VARCHAR2 -- added as part of CCR0010172
                                                              );

    PROCEDURE mail_hold_report (p_out_chr_errbuf    OUT VARCHAR2,
                                p_out_chr_retcode   OUT VARCHAR2);

    PROCEDURE send_mail_header (p_in_chr_msg_from IN VARCHAR2, p_in_chr_msg_to IN VARCHAR2, p_in_chr_msg_subject IN VARCHAR2
                                , p_out_num_status OUT NUMBER);

    PROCEDURE send_mail_line (p_in_chr_msg_text   IN     VARCHAR2,
                              p_out_num_status       OUT NUMBER);

    PROCEDURE send_mail_close (p_out_num_status OUT NUMBER);
END xxdo_ont_order_update_pkg;
/


GRANT EXECUTE ON APPS.XXDO_ONT_ORDER_UPDATE_PKG TO SOA_INT
/
