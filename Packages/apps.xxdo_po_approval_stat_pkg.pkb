--
-- XXDO_PO_APPROVAL_STAT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_APPROVAL_STAT_PKG"
AS
    /******************************************************************************
       NAME:       XXPO_PO_APPROVAL_STAT_PKG
       PURPOSE:    To get the approved PO's.

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        11/29/2016   Infosys            1. Created this package.
       2.0        04/25/2017   Bala Murugesan     Modified to include the pos
                                                  If the po shipments are modified;
                                                  Changes identified by INCLUDE_PLLA
       3.0        08/07/2017   Infosys            CCR0006518- Commented UNIONALL for Intercompany SO
       4.0        08/12/2018  Greg Jensen         CCR0007435- Check for IR receipts for Interco
       5.0        11/01/2019  Greg Jensen         CCR0008186 - APAC CI
       6.0        03/24/2020  Aravind Kannuri     CCR0008324 - Prod Issue Fix
       7.0        03/03/2021  Satyanarayana Kotha CCR0009182 - POC and ASN Changes
       8.0        10/20/2021  Shivanshu           CCR0009609 - EBS: P2P: POA Enhancements
    ******************************************************************************/
    g_num_request_id   NUMBER := fnd_global.conc_request_id;
    g_num_user_id      NUMBER := fnd_global.user_id;


    --***************************************************************************
    --                (c) Copyright Deckers
    --                     All rights reserved
    -- ***************************************************************************
    --
    -- Package Name:  XXPO_PO_APPROVAL_STAT_PKG
    -- PROCEDURE Name :XXDO_PO_APPRV_STAT_PROC
    -- Description:  This PROCEDURE to extract details of Approved PO's.

    -- DEVELOPMENT MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2016/28/11   Infosys              1.0.0    Initial version
    -- ***************************************************************************

    --Retrieve the date range based onthe conncurrent request log or run time
    FUNCTION Get_Display_Date (pd_date IN DATE)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN TO_CHAR (pd_date, 'DD-MON-YYYY HH24:MI:SS');
    END;

    --Return the previous run of the concurrent request for the program of the passed in request_id
    FUNCTION Get_Last_Conc_Req_Run (pn_request_id IN NUMBER)
        RETURN DATE
    IS
        ld_last_start_date         DATE;
        ln_concurrent_program_id   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Get Last Conc Req Ren - Start');
        fnd_file.put_line (fnd_file.LOG, 'REQUEST ID:  ' || pn_request_id);

        --Get the Concurrent program for the current running request
        BEGIN
            SELECT concurrent_program_id
              INTO ln_concurrent_program_id
              FROM fnd_concurrent_requests
             WHERE request_id = pn_request_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            --No occurnace running just return NULL
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No program found');
                RETURN NULL;
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'CC REQ ID : ' || ln_concurrent_program_id);

        BEGIN
            --Find the last occurance of this request
            SELECT MAX (actual_start_date)
              INTO ld_last_start_date
              FROM fnd_concurrent_requests
             WHERE     concurrent_program_id = ln_concurrent_program_id
                   AND STATUS_CODE = 'C' --Only count completed tasks to not limit data to any erroring out.
                   AND request_id != pn_request_id; --Don't include the current active request
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No prior occurance found');
                RETURN NULL;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'LAST START DATE : ' || Get_Display_Date (ld_last_start_date));

        RETURN ld_last_start_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;


    PROCEDURE Get_Date_Range (pd_start_date   IN OUT DATE,
                              pd_end_date     IN OUT DATE)
    IS
        --Get the last execution of the CC Request
        ld_last_cc_date   DATE := Get_Last_Conc_Req_Run (g_num_request_id);
    BEGIN
        --use current date/time for end date
        pd_end_date   := SYSDATE;

        --special case if launch time is between 11PM and 1 AM then get range as last 24 hours
        --Note as this spans midnight. For better time comparison  subtract 2hrs
        IF     TO_CHAR (SYSDATE - 2 / 24, 'HH24MI') < '2300'
           AND TO_CHAR (SYSDATE - 2 / 24, 'HH24MI') > '2100'
        THEN
            pd_start_date   := SYSDATE - 1;
            RETURN;
        END IF;


        IF ld_last_cc_date IS NULL
        THEN
            pd_start_date   := SYSDATE - 3 / 24; --If no run then use current date -3 hours
        ELSE
            pd_start_date   := ld_last_cc_date - 1 / 48; --If there is a last CCRequest then use last start date - 30 min
        END IF;
    END;

    --Begin CCR0008186
    PROCEDURE update_po_interco_price (pv_error_buf OUT VARCHAR2)
    IS
        --Cursor of PO lines having PO update flag set
        CURSOR c_PO_list IS
            SELECT pla.po_line_id
              FROM po_lines_all pla, po_line_locations_all plla
             WHERE     pla.po_line_id = plla.po_line_id
                   AND NVL (plla.attribute6, 'N') = 'Y'
                   AND EXISTS                   --This is an intercompany line
                           (SELECT NULL
                              FROM oe_order_lines_all oola
                             WHERE     1 = 1
                                   --oola.context != 'DO eCommerce'             --Commented as per CCR0008324
                                   AND NVL (oola.context, 'N') !=
                                       'DO eCommerce' --Added as per CCR0008324
                                   AND oola.attribute16 =
                                       TO_CHAR (plla.line_location_id)
                                   AND oola.order_source_id = 10);

        ln_new_price   NUMBER;
    BEGIN
        FOR rec IN c_po_list
        LOOP
            --Get new price

            ln_new_price   :=
                XXD_PO_INTERCO_PRICE_PKG.get_interco_price (rec.po_line_id);

            IF ln_new_price IS NOT NULL
            THEN
                UPDATE po_lines_all
                   SET attribute3 = TO_CHAR (ROUND (ln_new_price, 2)), last_update_date = SYSDATE, last_updated_by = g_num_user_id
                 WHERE po_line_id = rec.po_line_id;
            ELSE
                UPDATE po_lines_all
                   SET attribute3 = NULL, last_update_date = SYSDATE, last_updated_by = g_num_user_id
                 WHERE po_line_id = rec.po_line_id;
            END IF;

            UPDATE po_line_locations_all
               SET attribute6 = 'N', last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE po_line_id = rec.po_line_id;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_buf   := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END;

    --Begin CCR0008186

    PROCEDURE xxdo_po_apprv_stat_proc (pn_retcode              OUT NUMBER,
                                       pv_error_buf            OUT VARCHAR2,
                                       pv_reprocess         IN     VARCHAR2, -- Added procedure w.r.t to version 8.0
                                       pv_dummy             IN     VARCHAR2, -- Added procedure w.r.t to version 8.0
                                       pn_reprocess_hours   IN     NUMBER) -- Added procedure w.r.t to version 8.0
    IS
        pd_from_date   DATE;
        pd_end_date    DATE;
    BEGIN
        --This is the original concurrent request. Get the dates as per the old method
        Get_Date_Range (pd_from_date, pd_end_date);

        xxdo_po_apprv_stat_proc (pn_retcode,
                                 pv_error_buf,
                                 pd_from_date,
                                 pd_end_date,
                                 pv_reprocess,
                                 pn_reprocess_hours);
    END;

    PROCEDURE xxdo_po_apprv_stat_proc (pn_retcode OUT NUMBER, pv_error_buf OUT VARCHAR2, pd_from_date IN DATE
                                       , pd_to_date IN DATE, pv_reprocess IN VARCHAR2, -- Added procedure w.r.t to version 8.0
                                                                                       pn_reprocess_hours IN NUMBER) -- Added procedure w.r.t to version 8.0
    IS
        CURSOR c_approved_po (p_from_date DATE, p_to_date DATE)
        IS
            SELECT po_number
              FROM xxdo.xxdoint_po_header_v
             WHERE po_number IN
                       (SELECT pha.segment1 po_number
                          FROM apps.po_line_locations_all plla, apps.oe_drop_ship_sources dss, apps.po_headers_all pha,
                               apps.oe_order_lines_all oola
                         WHERE     plla.line_location_id =
                                   dss.line_location_id
                               AND oola.line_id = dss.line_id
                               AND pha.po_header_id = plla.po_header_id
                               AND oola.last_update_date >= p_from_date
                               AND oola.last_update_date <= p_to_date
                               AND pha.attribute11 = 'Y' --Start CCR0006518  not to send POA's when SO lines gets updated for Intercompany ISO's
                                                        /* UNION ALL
                                                         SELECT pha.segment1 po_number
                                                           FROM apps.po_line_locations_all plla,
                                                                apps.oe_order_lines_all oola,
                                                                apps.po_headers_all pha
                                                          WHERE     oola.attribute16 =
                                                                       TO_CHAR (plla.line_location_id)
                                                                AND oola.org_id = plla.org_id
                                                                AND plla.po_header_id = pha.po_header_id
                                                                AND oola.last_update_date >= p_from_date
                                                                AND oola.last_update_date <= p_to_date
                                                                AND pha.attribute11 = 'Y' */
                                                        --End CCR0006518  not to send POA's when SO lines gets updated for Intercompany ISO's
                                                        )
            UNION
            SELECT ph.po_number
              FROM xxdo.xxdoint_po_header_v ph,
                   apps.po_headers_all pha,
                   (  SELECT stat.po_number, MAX (creation_date) poa_date --CCR0008186
                        FROM xxdo_po_approval_stat stat
                       WHERE process_status = 'Y'
                    GROUP BY stat.po_number) poa
             WHERE     ph.po_number = pha.segment1
                   AND pha.segment1 = poa.po_number(+)
                   AND last_update_date >=
                       NVL2 (poa_date,
                             GREATEST (p_from_date, poa_date),
                             p_from_date)            --CCR0008186 --CCR0008186
                   AND last_update_date <= p_to_date
                   AND pha.attribute11 = 'Y'
            UNION
            SELECT ph.po_number
              FROM xxdo.xxdoint_po_header_v ph,
                   po.po_lines_all pl,
                   apps.po_headers_all pha,
                   (  SELECT stat.po_number, MAX (creation_date) poa_date --CCR0008186
                        FROM xxdo_po_approval_stat stat
                       WHERE process_status = 'Y'
                    GROUP BY stat.po_number) poa,
                   apps.po_line_locations_all pll              -- INCLUDE_PLLA
             WHERE     ph.po_header_id = pl.po_header_id
                   AND ph.po_number = pha.segment1
                   AND pha.po_header_id = pl.po_header_id
                   AND pha.segment1 = poa.po_number(+)
                   -- INCLUDE_PLLA - Start
                   --                AND pl.last_update_date >= p_from_date
                   --                AND pl.last_update_date <= p_to_date
                   AND ((pl.last_update_date >= NVL2 (poa_date, GREATEST (p_from_date, poa_date), p_from_date) --CCR0008186 GREATEST (p_from_date, nvl(poa_date,p_from_date))  --CCR0008186
                                                                                                               AND pl.last_update_date <= p_to_date) OR (pll.last_update_date >= NVL2 (poa_date, GREATEST (p_from_date, poa_date), p_from_date) --CCR0008186  --CCR0008186
                                                                                                                                                                                                                                                AND pll.last_update_date <= p_to_date))
                   AND pll.po_line_id = pl.po_line_id
                   -- INCLUDE_PLLA - End
                   AND pha.attribute11 = 'Y'
            UNION --Added check to receipt transactions to pick up US receipts
            SELECT ph.po_number
              FROM xxdo.xxdoint_po_header_v ph, po.po_line_locations_all pll, rcv_transactions rt,
                   hr_all_organization_units hr, apps.po_headers_all pha
             WHERE     ph.po_header_id = pll.po_header_id
                   AND ph.po_number = pha.segment1
                   AND pha.po_header_id = pll.po_header_id
                   AND rt.source_document_code = 'PO'
                   AND rt.transaction_type = 'RECEIVE'
                   AND pha.org_id = hr.organization_id
                   AND hr.name = 'Deckers US OU'
                   AND pha.po_header_id = rt.po_header_id
                   AND pll.line_location_id = rt.po_line_location_id
                   AND rt.creation_date >= p_from_date
                   AND rt.creation_date <= p_to_date
                   AND pha.attribute11 = 'Y'
            UNION
              --Added for CCR0007435 - Check linked IR ASN receipts for Intercompany
              SELECT ph.po_number
                FROM xxdo.xxdoint_po_header_v ph, apps.po_headers_all pha, po_line_locations_all plla,
                     po.rcv_shipment_lines rsl, oe_order_lines_all oola, wsh_delivery_details wdd,
                     mtl_material_transactions mmt, rcv_shipment_lines rsl_ir, rcv_transactions rt
               WHERE     ph.po_number = pha.segment1
                     AND pha.po_header_id = plla.po_header_id
                     AND plla.line_location_id = rsl.po_line_location_id
                     AND TO_NUMBER (rsl.attribute3) = oola.line_id
                     AND oola.line_id = wdd.source_line_id
                     AND wdd.delivery_detail_id = mmt.picking_line_id
                     AND mmt.transaction_id = rsl_ir.mmt_transaction_id
                     AND mmt.inventory_item_id = rsl_ir.item_id
                     AND rsl_ir.shipment_line_id = rt.shipment_line_id
                     AND rt.creation_date >= p_from_date
                     AND rt.creation_date <= p_to_date
                     AND pha.attribute11 = 'Y'
            --End addition for  CCR0007435
            GROUP BY ph.po_number
            --Added for CCR0009182
            UNION
              SELECT pha.segment1 po_number
                FROM apps.po_line_locations_all plla, apps.oe_order_lines_all oola, apps.po_headers_all pha
               WHERE     oola.attribute16 = TO_CHAR (plla.line_location_id)
                     AND oola.org_id = plla.org_id
                     AND plla.po_header_id = pha.po_header_id
                     AND oola.last_update_date >= p_from_date
                     AND oola.last_update_date <= p_to_date
                     AND pha.attribute10 = 'DIRECT_SHIP'
                     AND oola.flow_status_code = 'CLOSED'
            GROUP BY pha.segment1;

        --END for CCR0009182
        lv_chr_po_num           VARCHAR2 (20) := NULL;
        lv_chr_exist_po         VARCHAR2 (1) := NULL;
        lv_chr_auth_stat        po_headers_all.authorization_status%TYPE := NULL;
        lv_chr_po_approv_stat   VARCHAR2 (10) := NULL;
        lv_chr_process_stat     VARCHAR2 (1) := NULL;
        lv_chr_ora_err_msg      VARCHAR2 (2000) := NULL;
        lv_num_req_id           NUMBER := 0;
        lv_num_created_by       NUMBER := 0;
        lv_dt_creation_date     DATE := NULL;
        lv_last_update_date     DATE := NULL;
        lv_last_updated_by      NUMBER := 0;
        ld_date_to_date         DATE := pd_to_date;
        n_recs                  NUMBER;
    BEGIN
        --Start of block to check the program for the first run--
        fnd_file.put_line (
            fnd_file.LOG,
               '*** xxdo_po_apprv_stat_proc Start at: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        fnd_file.put_line (fnd_file.LOG, '');
        fnd_file.put_line (fnd_file.LOG,
                           'FROM DATE : ' || get_display_date (pd_from_date));
        fnd_file.put_line (
            fnd_file.LOG,
            'TO DATE   : ' || get_display_date (ld_date_to_date));

        IF pv_reprocess = 'Y'  -- Added procedure w.r.t to version 8.0 (start)
        THEN
            UPDATE apps.xxdo_po_approval_stat
               SET batch_id   = NULL
             WHERE     process_status IS NULL
                   AND batch_id IS NOT NULL
                   AND creation_date <
                       SYSDATE - NVL (pn_reprocess_hours, 24) / 24;
        END IF;                   --Added procedure w.r.t to version 8.0 (end)


        -- update PO Interco Price CCR0008186
        update_po_interco_price (lv_chr_ora_err_msg);

        IF lv_chr_ora_err_msg IS NOT NULL
        THEN
            pv_error_buf   :=
                'Error occurred updating PO Prices ; ' || lv_chr_ora_err_msg;
            fnd_file.put_line (fnd_file.LOG, pv_error_buf);
            RETURN;
        ELSE
            --Update to_date to sysdate to capture any price updates from interco_price_update
            ld_date_to_date   := SYSDATE;
        END IF;

        --End CCR0008186


        --Start of loop for main program loop to get approved POs--
        FOR rec_approved_po IN c_approved_po (pd_from_date, ld_date_to_date)
        LOOP
            lv_chr_po_num         := rec_approved_po.po_number; --Storing the Po Number in the variable.

            --Start of block to store authorization status and other who columns for authorized POs--
            BEGIN
                SELECT authorization_status
                  INTO lv_chr_auth_stat
                  FROM po_headers_all
                 WHERE segment1 = lv_chr_po_num;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'The authorization status for PO '
                    || lv_chr_po_num
                    || ' is: '
                    || lv_chr_auth_stat);

                --Start of segment to store approval status for authorized POs--
                IF (lv_chr_auth_stat = 'APPROVED')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updating the approval status as ''N'' for staging table record');
                    lv_chr_po_approv_stat   := 'N';
                    lv_chr_ora_err_msg      := NULL;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_chr_po_approv_stat   := 'E';
                    lv_chr_ora_err_msg      := 'PO has not yet Authorized';
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updating the approval status as ''E'' for staging table record as PO is not authorized');
                WHEN OTHERS
                THEN
                    pv_error_buf   :=
                           'Unexcepted error in fetching the authorization status of the program '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_error_buf);
            END;

            --Start of segment to store process status, request id and who columns in variable for POs--
            lv_chr_process_stat   := NULL;
            lv_num_req_id         := g_num_request_id;
            lv_num_created_by     := fnd_global.user_id;
            lv_dt_creation_date   := SYSDATE;
            lv_last_update_date   := SYSDATE;
            lv_last_updated_by    := fnd_global.user_id;
            --End of segment to store process status, request id and who columns in variable for POs--

            fnd_file.put_line (
                fnd_file.LOG,
                   'Check PO start: '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                || ' *** PO # '
                || lv_chr_po_num);

            --check if this PO is already in the table and queued for send
            SELECT COUNT (*)
              INTO n_recs
              FROM xxdo_po_approval_stat
             WHERE     po_number = lv_chr_po_num
                   AND process_status IS NULL --CCR0008186 Do not insert if PO exists regarless of status.
                   AND BATCH_ID IS NULL; --Added procedure w.r.t to version 8.0 (end)

            fnd_file.put_line (
                fnd_file.LOG,
                   'Check PO end: '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                || ' ***');

            --There are no instances of this PO in the table.Add the PO.
            IF n_recs = 0
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Do Insert for PO : ' || lv_chr_po_num);

                --Start of segment to insert all values stored in variables into the staging table for POs--
                INSERT INTO xxdo_po_approval_stat (po_number,
                                                   po_approval_status,
                                                   process_status,
                                                   oracle_error_message,
                                                   request_id,
                                                   created_by,
                                                   creation_date,
                                                   last_update_date,
                                                   last_updated_by)
                         VALUES (lv_chr_po_num,
                                 lv_chr_po_approv_stat,
                                 lv_chr_process_stat,
                                 lv_chr_ora_err_msg,
                                 lv_num_req_id,
                                 lv_num_created_by,
                                 lv_dt_creation_date,
                                 lv_last_update_date,
                                 lv_last_updated_by);
            --End of segment to insert all values stored in variables into the staging table for POs--
            END IF;
        END LOOP;    --End of loop for main program loop to get approved POs--

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               'End of loop to fetch PO records at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '');

        fnd_file.put_line (
            fnd_file.LOG,
            'Resetting the status of POs which were not authorized in previous runs');

        fnd_file.put_line (fnd_file.LOG, '');


        UPDATE xxdo_po_approval_stat
           SET po_approval_status = 'N', oracle_error_message = NULL, last_update_date = SYSDATE,
               last_updated_by = fnd_global.user_id
         WHERE     po_approval_status = 'E'
               AND po_number IN (SELECT segment1
                                   FROM po_headers_all
                                  WHERE authorization_status = 'APPROVED');

        IF (SQL%FOUND)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Total of : '
                || SQL%ROWCOUNT
                || 'records updated for errored status in staging table');
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'No records to update');
        END IF;

        COMMIT;
        fnd_file.put_line (fnd_file.LOG, '');
        fnd_file.put_line (
            fnd_file.LOG,
               '*** xxdo_po_apprv_stat_proc - End at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_buf   :=
                'Unexcepted error in the main program ' || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, pv_error_buf);
    END xxdo_po_apprv_stat_proc;

    --Added procedure w.r.t to version 8.0(start)
    PROCEDURE xxd_gen_poa_batch (pn_batch_id OUT NUMBER)
    AS
        ln_poa_batch_seq   NUMBER;
        ln_row_cnt         NUMBER;
        lv_error_message   VARCHAR2 (1000) := NULL;
    BEGIN
        ln_poa_batch_seq   := xxdo.xxd_po_approval_batch_s.NEXTVAL;

        UPDATE apps.xxdo_po_approval_stat
           SET batch_id   = ln_poa_batch_seq
         WHERE process_status IS NULL AND batch_id IS NULL;

        ln_row_cnt         := SQL%ROWCOUNT;

        IF ln_row_cnt > 0
        THEN
            pn_batch_id   := ln_poa_batch_seq;
        ELSE
            pn_batch_id   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   := ' Unable to update the batch id' || SQLERRM;
            pn_batch_id        := NULL;
    END xxd_gen_poa_batch;
--Added procedure w.r.t to version 8.0 (end)


END XXDO_PO_APPROVAL_STAT_PKG;
/


GRANT EXECUTE ON APPS.XXDO_PO_APPROVAL_STAT_PKG TO SOA_INT
/
