--
-- XXDO_EDI_ANALYSIS_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_EDI_ANALYSIS_PK"
AS
    PROCEDURE analyse_edi_inbound
    IS
        l_num_query_id   NUMBER;
        l_err_buf        VARCHAR2 (1000);
        l_ret_code       VARCHAR2 (1000);
        l_num_days       NUMBER := 3;
    BEGIN
        BEGIN
            DELETE xxdo_intf_orders;

            COMMIT;

            INSERT INTO xxdo.xxdo_intf_orders (customer_po_number,
                                               cancel_date,
                                               brand,
                                               ordered_date,
                                               request_date,
                                               creation_date)
                  SELECT customer_po_number, TO_DATE (attribute1, 'YYYY/MM/DD'), attribute5,
                         TRUNC (ordered_date), TRUNC (request_date), TRUNC (creation_date)
                    FROM ONT.oe_headers_iface_all
                   WHERE     order_source_id = 6
                         AND TRUNC (creation_date) >=
                             TRUNC (SYSDATE - l_num_days)
                         AND TRUNC (creation_date) < TRUNC (SYSDATE)
                         AND operation_code = 'INSERT'
                GROUP BY customer_po_number, attribute1, attribute5,
                         TRUNC (ordered_date), TRUNC (creation_date), TRUNC (request_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
                ROLLBACK;
        END;

        BEGIN
            DELETE xxdo.xxdo_ebs_orders;

            COMMIT;

            INSERT INTO xxdo.xxdo_ebs_orders (customer_po_number, cancel_date, brand, ordered_date, request_date, creation_date
                                              , order_number)
                  SELECT cust_po_number, TO_DATE (attribute1, 'YYYY/MM/DD hh24:Mi:ss'), attribute5,
                         TRUNC (ordered_date), TRUNC (request_date), TRUNC (creation_date),
                         order_number
                    FROM ONT.oe_order_headers_all
                   WHERE     order_source_id = 6
                         AND TRUNC (creation_date) >=
                             TRUNC (SYSDATE - l_num_days)
                         AND TRUNC (creation_date) < TRUNC (SYSDATE)
                GROUP BY cust_po_number, attribute1, attribute5,
                         TRUNC (ordered_date), TRUNC (request_date), TRUNC (creation_date),
                         order_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
                ROLLBACK;
        END;



        BEGIN
            DELETE FROM xxdo.xxdo_bsa_orders;

            COMMIT;

            INSERT INTO xxdo_bsa_orders (customer_po_number,
                                         blanket_order,
                                         creation_date,
                                         sold_to_org_id,
                                         account_number,
                                         customer_name)
                  SELECT cust_po_number, obh.ORDER_NUMBER, TRUNC (obh.creation_date),
                         obh.sold_to_org_id, cust.account_number, cust.customer_name
                    FROM ont.oe_blanket_headers_all obh, XXDO.xxdoint_ar_cust_unified_v cust
                   WHERE     obh.sold_to_org_id = cust.customer_id
                         AND TRUNC (obh.creation_date) >=
                             TRUNC (SYSDATE - l_num_days)
                         AND TRUNC (obh.creation_date) < TRUNC (SYSDATE)
                GROUP BY cust_po_number, obh.ORDER_NUMBER, TRUNC (obh.creation_date),
                         obh.sold_to_org_id, cust.account_number, cust.customer_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
                ROLLBACK;
        END;



        UPDATE xxdo.xxdo_b2b_orders
           SET exists_in_SoA   = 'N';

        UPDATE xxdo.xxdo_bam_orders
           SET exists_in_interface = 'N', notified = 'N', exists_in_ebs = 'N',
               blanket_order_created = 'N', assignee = NULL;

        UPDATE xxdo.xxdo_b2b_orders
           SET exists_in_SoA   = 'Y'
         WHERE b2b_message_id IN
                   (SELECT app_trans_key FROM xxdo.xxdo_bam_orders);

        UPDATE xxdo.xxdo_bam_orders
           SET exists_in_interface   = 'Y'
         WHERE order_number IN
                   (SELECT customer_po_number FROM xxdo.xxdo_intf_orders);


        UPDATE xxdo.xxdo_bam_orders
           SET notified   = 'Y'
         WHERE order_number IN
                   (SELECT customer_po_number FROM xxdo.xxdo_notified_orders);


        UPDATE xxdo.xxdo_bam_orders x
           SET exists_in_ebs   = 'Y',
               ebs_order_number   =
                   (SELECT y.order_number
                      FROM xxdo.xxdo_ebs_orders y
                     WHERE     y.customer_po_number = x.order_number
                           AND ROWNUM = 1)
         WHERE order_number IN
                   (SELECT customer_po_number FROM xxdo.xxdo_ebs_orders);


        UPDATE xxdo.xxdo_bam_orders
           SET blanket_order_created   = 'Y'
         WHERE order_number IN
                   (SELECT customer_po_number FROM xxdo.xxdo_bsa_orders);


        UPDATE xxdo.xxdo_bam_orders a
           SET assignee   =
                   (SELECT b.asignee
                      FROM xxdo.xxdo_validation_tasks b
                     WHERE b.order_number = a.order_number AND ROWNUM = 1)
         WHERE order_number IN (SELECT b.order_number
                                  FROM xxdo.xxdo_validation_tasks b);

        COMMIT;

        SELECT query_id
          INTO l_num_query_id
          FROM XXDO_COMMON_DAILY_STATUS_TBL
         WHERE query_desc LIKE '%EDI INBOUND ERROR ANALYSIS%';

        xxdo_common_daily_status_pkg.main (l_err_buf,
                                           l_ret_code,
                                           l_num_query_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END analyse_edi_inbound;
END XXDO_EDI_ANALYSIS_PK;
/


GRANT EXECUTE ON APPS.XXDO_EDI_ANALYSIS_PK TO SOA_INT
/

GRANT EXECUTE ON APPS.XXDO_EDI_ANALYSIS_PK TO XXDO
/
