--
-- XXDOEC_OEOL_WF_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_OEOL_WF_PKG"
AS
    PROCEDURE update_line_custom_status (
        p_line_id       IN     NUMBER,
        p_status_code   IN     VARCHAR2,
        p_reason_code   IN     VARCHAR2 DEFAULT NULL,
        x_rtn_sts          OUT VARCHAR2,
        x_rtn_msg          OUT VARCHAR2);

    PROCEDURE check_latest_acceptable_date (itemtype    IN     VARCHAR2,
                                            itemkey     IN     VARCHAR2,
                                            actid       IN     NUMBER,
                                            funcmode    IN     VARCHAR2,
                                            resultout   IN OUT VARCHAR2);

    PROCEDURE mark_fraud_check (itemtype    IN     VARCHAR2,
                                itemkey     IN     VARCHAR2,
                                actid       IN     NUMBER,
                                funcmode    IN     VARCHAR2,
                                resultout   IN OUT VARCHAR2);

    PROCEDURE mark_pg_authorization (itemtype    IN     VARCHAR2,
                                     itemkey     IN     VARCHAR2,
                                     actid       IN     NUMBER,
                                     funcmode    IN     VARCHAR2,
                                     resultout   IN OUT VARCHAR2);

    PROCEDURE mark_shipment_email (itemtype    IN     VARCHAR2,
                                   itemkey     IN     VARCHAR2,
                                   actid       IN     NUMBER,
                                   funcmode    IN     VARCHAR2,
                                   resultout   IN OUT VARCHAR2);

    PROCEDURE mark_pg_capture_funds (itemtype    IN     VARCHAR2,
                                     itemkey     IN     VARCHAR2,
                                     actid       IN     NUMBER,
                                     funcmode    IN     VARCHAR2,
                                     resultout   IN OUT VARCHAR2);

    PROCEDURE mark_cancel_actions (itemtype    IN     VARCHAR2,
                                   itemkey     IN     VARCHAR2,
                                   actid       IN     NUMBER,
                                   funcmode    IN     VARCHAR2,
                                   resultout   IN OUT VARCHAR2);

    PROCEDURE mark_cancel_email (itemtype    IN     VARCHAR2,
                                 itemkey     IN     VARCHAR2,
                                 actid       IN     NUMBER,
                                 funcmode    IN     VARCHAR2,
                                 resultout   IN OUT VARCHAR2);

    PROCEDURE cancel_line (itemtype IN VARCHAR2, itemkey IN VARCHAR2, actid IN NUMBER
                           , funcmode IN VARCHAR2, resultout IN OUT VARCHAR2);

    PROCEDURE mark_pg_chargeback (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2);

    PROCEDURE mark_receipt_email (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2);

    PROCEDURE get_do_order_type (itemtype    IN     VARCHAR2,
                                 itemkey     IN     VARCHAR2,
                                 actid       IN     NUMBER,
                                 funcmode    IN     VARCHAR2,
                                 resultout   IN OUT VARCHAR2);

    PROCEDURE get_do_return_type (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2);

    PROCEDURE mark_ca_ship_notif (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2);

    PROCEDURE mark_ca_ship_email (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2);

    PROCEDURE mark_ca_refund_notif (itemtype    IN     VARCHAR2,
                                    itemkey     IN     VARCHAR2,
                                    actid       IN     NUMBER,
                                    funcmode    IN     VARCHAR2,
                                    resultout   IN OUT VARCHAR2);

    PROCEDURE mark_ca_receipt_email (itemtype    IN     VARCHAR2,
                                     itemkey     IN     VARCHAR2,
                                     actid       IN     NUMBER,
                                     funcmode    IN     VARCHAR2,
                                     resultout   IN OUT VARCHAR2);

    PROCEDURE is_customized_product (itemtype    IN     VARCHAR2,
                                     itemkey     IN     VARCHAR2,
                                     actid       IN     NUMBER,
                                     funcmode    IN     VARCHAR2,
                                     resultout   IN OUT VARCHAR2);

    PROCEDURE mark_to_send_to_m2o (itemtype    IN     VARCHAR2,
                                   itemkey     IN     VARCHAR2,
                                   actid       IN     NUMBER,
                                   funcmode    IN     VARCHAR2,
                                   resultout   IN OUT VARCHAR2);

    PROCEDURE mark_order_ack_email (itemtype    IN     VARCHAR2,
                                    itemkey     IN     VARCHAR2,
                                    actid       IN     NUMBER,
                                    funcmode    IN     VARCHAR2,
                                    resultout   IN OUT VARCHAR2);

    PROCEDURE mark_sfs_action (itemtype    IN     VARCHAR2,
                               itemkey     IN     VARCHAR2,
                               actid       IN     NUMBER,
                               funcmode    IN     VARCHAR2,
                               resultout   IN OUT VARCHAR2);

    PROCEDURE update_source_type_code (itemtype    IN     VARCHAR2,
                                       itemkey     IN     VARCHAR2,
                                       actid       IN     NUMBER,
                                       funcmode    IN     VARCHAR2,
                                       resultout   IN OUT VARCHAR2);

    PROCEDURE CHECK_FLAG_STAFF (itemtype    IN            VARCHAR2,
                                itemkey     IN            VARCHAR2,
                                actid       IN            NUMBER,
                                funcmode    IN            VARCHAR2,
                                resultout      OUT NOCOPY VARCHAR2);
END xxdoec_oeol_wf_pkg;
/
