--
-- XXDOEC_FILE_WORKER  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_FILE_WORKER"
AS
    /******************************************************************************
       NAME:       xxdoec_file_worker
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        11/26/2012      mbacigalupi       1. Created this package.
    ******************************************************************************/
    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I')
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);

        INSERT INTO xxdo.XXDOEC_PROCESS_ORDER_LOG
                 VALUES (xxdo.XXDOEC_SEQ_PROCESS_ORDER.NEXTVAL,
                         MESSAGE,
                         CURRENT_TIMESTAMP);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END msg;

    PROCEDURE GetOrderData (p_list       IN     t_order_array,
                            order_list      OUT t_order_list)
    AS
        DCDLog      DCDLog_type
                        := DCDLog_type (P_CODE => -10100, P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 2
                                        , P_TRACELEVEL => 1, P_DEBUG => 0);
        l_rc        NUMBER := 0;
        l_err_num   NUMBER := -1;                             --error handling
        l_err_msg   VARCHAR2 (100) := '';                     --error handling
        l_message   VARCHAR2 (1000) := '';            --for message processing
    BEGIN
        --Report the parameters we were given (orderId's)
        FOR i IN p_list.FIRST .. p_list.LAST
        LOOP
            DCDLog.AddParameter ('orderId', p_list (i), 'VARCHAR2');
        END LOOP;

        l_rc   := DCDLog.LogInsert ();

        IF (l_rc <> 1)
        THEN
            msg (DCDLog.l_message);
        END IF;

        --Delete anything this process may have left in the global
        --temporary table.

        DELETE FROM xxdoec_file_worker_table;

        --Mass dump the orderId's into the global temporary table

        FORALL i IN p_list.FIRST .. p_list.LAST
            INSERT INTO apps.xxdoec_file_worker_table (orderId)
                 VALUES (p_list (i));

        --Update the orderId's just in case we were given a quote'"'

        UPDATE apps.xxdoec_file_worker_table
           SET orderId   = TRANSLATE (orderId, 'A"', 'A');

        --Join the oracle EBS tables to our global temporary table and return
        --the data we need for sending the return confirmation email.

        OPEN order_list FOR
            SELECT DISTINCT d.orderId,
                            b.location shipToName,
                            f.email_address billToEmail,
                            CASE
                                WHEN SUBSTR (
                                         e.account_number,
                                         1,
                                         2) =
                                     '90'
                                THEN
                                    SUBSTR (e.account_number,
                                            3)
                                ELSE
                                    e.account_number
                            END account_number,
                            h.website_id,
                            h.erp_language,
                            TO_CHAR (c.ordered_date,
                                     'YYYY-MM-DD') ordered_date
              FROM apps.hz_cust_site_uses_all b
                   JOIN apps.oe_order_headers_all c
                       ON c.ship_to_org_id = b.site_use_id
                   JOIN apps.xxdoec_file_worker_table d
                       ON d.orderid = c.cust_po_number
                   JOIN apps.hz_cust_accounts e
                       ON e.cust_account_id = c.sold_to_org_id
                   JOIN apps.hz_parties f ON e.party_id = f.party_id
                   -- MV 2016-11-10 - commented by suggestion from Bala
                   --JOIN apps.oe_order_lines_all g ON c.header_id=g.header_id
                   JOIN apps.xxdoec_country_brand_params h
                       ON h.erp_org_id = c.org_id
             -- MV 2016-11-03 - commented
             --AND h.inv_org_id=g.ship_from_org_id
             --AND h.brand_name=g.demand_class_code
             WHERE     h.website_id NOT LIKE '%AMZN%'
                   AND h.website_id = RTRIM (LTRIM (e.attribute18));
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                l_err_num             := SQLCODE;
                l_err_msg             := SUBSTR (SQLERRM, 1, 100);
                l_message             := 'ERROR GetOrderData:  ';
                l_message             :=
                       l_message
                    || ' err_num='
                    || TO_CHAR (l_err_num)
                    || ' err_msg='
                    || l_err_msg
                    || '.';
                DCDLog.ChangeCode (P_CODE => -10100, P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 1
                                   , P_TRACELEVEL => 1, P_DEBUG => 0);
                DCDLog.FunctionName   := 'GetOrderData';
                DCDLog.AddParameter ('SQLCODE',
                                     TO_CHAR (l_err_num),
                                     'NUMBER');
                DCDLog.AddParameter ('SQLERRM', l_err_msg, 'VARCHAR2');
                l_rc                  := DCDLog.LogInsert ();

                IF (l_rc <> 1)
                THEN
                    msg (DCDLog.l_message);
                END IF;
            END;
    END;
END xxdoec_file_worker;
/
