--
-- XXDO_INT_WMS_UTIL  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INT_WMS_UTIL"
AS
    --Added  CCR0006561
    --Get the timezone for the passed in Site
    --If the timezone is not found for this site default to US/Los Angeles
    FUNCTION get_wms_timezone (p_site_id IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_timezone   VARCHAR2 (50);
    BEGIN
        BEGIN
            --Lookup timezone for slocation / site
            SELECT hra.timezone_code
              INTO l_timezone
              FROM apps.hr_locations_all hra, apps.hr_organization_units hou
             WHERE     hra.attribute1 = p_site_id
                   AND hou.location_id = hra.location_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_timezone   := NULL;
        END;

        --If timezone was not found default to server timezone (US/Los Angeles)
        IF l_timezone IS NULL
        THEN
            SELECT name
              INTO l_timezone
              FROM apps.hz_timezones_tl htt
             WHERE     htt.timezone_id =
                       apps.fnd_profile.VALUE ('SERVER_TIMEZONE_ID')
                   AND htt.language = 'US';
        END IF;

        RETURN l_timezone;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --Added  CCR0006561
    --Gets the offset between US/Goleta time and the timezone (timezone name from hz_timezone_tl)
    --Example get_offset('CET')-> .375 8/24
    FUNCTION get_offset (p_timezone IN VARCHAR2)
        RETURN NUMBER
    IS
        l_offset   NUMBER := 0;
    BEGIN
        SELECT -(SUM (gmt_deviation_hours) / 24)
          INTO l_offset
          FROM (SELECT -ht.gmt_deviation_hours AS gmt_deviation_hours
                  FROM apps.hz_timezones ht, apps.hz_timezones_tl htt
                 WHERE     htt.name = p_timezone
                       AND htt.language = 'US'
                       AND ht.timezone_id = htt.timezone_id
                UNION ALL
                SELECT gmt_deviation_hours
                  FROM apps.hz_timezones ht
                 WHERE timezone_id =
                       apps.fnd_profile.VALUE ('SERVER_TIMEZONE_ID'));

        RETURN l_offset;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    --Added  CCR0006561
    --Get the first of the next month for the current passed in date
    FUNCTION get_first_of_next_month (p_date IN DATE:= SYSDATE)
        RETURN DATE
    IS
        l_return_date   DATE;
    BEGIN
        SELECT TRUNC (ADD_MONTHS (p_date, 1), 'MM')
          INTO l_return_date
          FROM DUAL;

        RETURN l_return_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            --return 1st of curr month
            SELECT TRUNC (p_date, 'MONTH') INTO l_return_date FROM DUAL;

            RETURN l_return_date;
    END;

    --Get the organization_id for the passed in site
    FUNCTION get_wms_org_id (p_site_id VARCHAR2)
        RETURN NUMBER
    IS
        l_organization_id   NUMBER;
    BEGIN
        --DBMS_OUTPUT.put_line ('In get_wms_org_id..');

        BEGIN
            SELECT hou.organization_id
              INTO l_organization_id
              FROM apps.hr_locations_all hra, apps.hr_organization_units hou
             WHERE     hra.attribute1 = p_site_id
                   AND hou.location_id = hra.location_id;

            RETURN l_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
                RETURN NULL;
        END;
    END;

    FUNCTION get_wms_org_code (p_site_id VARCHAR2)
        RETURN VARCHAR2
    IS
        l_organization_code   VARCHAR2 (20);
    BEGIN
        -- DBMS_OUTPUT.put_line ('In get_wms_org_id..');

        BEGIN
            SELECT mp.organization_code
              INTO l_organization_code
              FROM apps.hr_locations_all hra, apps.hr_organization_units hou, apps.mtl_parameters mp
             WHERE     hra.attribute1 = p_site_id
                   AND hou.location_id = hra.location_id
                   AND hou.organization_id = mp.organization_id;

            RETURN l_organization_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
                RETURN NULL;
        END;
    END;

    --modified  CCR0006561
    --Gets the proper transaction applying EOM logic for transactions

    --p_shipment_date - transaction date from source
    --p_site_id      - file site_id
    --p_svr_date     - used only for testing - this will override the default of the current system date

    FUNCTION get_file_adjusted_time (p_shipment_date IN DATE, p_site_id IN VARCHAR2, p_svr_date IN DATE:= SYSDATE)
        RETURN DATE                                                         --
    IS
        l_offset           NUMBER;
        l_goleta_month     VARCHAR2 (30);
        l_3pl_month        VARCHAR2 (30);
        l_3pl_file_month   VARCHAR2 (30);
        --l_return_date    date;
        l_return_date      VARCHAR2 (50);
        l_timezone         VARCHAR2 (50);
        d_return_date      DATE;
    BEGIN
        --DBMS_OUTPUT.put_line ('p_site_id : ' || p_site_id);
        --get the timezone for the site
        --Modified  CCR0006561
        l_timezone   := get_wms_timezone (p_site_id);

        --DBMS_OUTPUT.put_line ('Timezone: ' || l_timezone);

        --Get the relevant Months/Dates for EOM Logic

        --Get Month in US/Goleta
        SELECT TO_CHAR (p_svr_date, 'MON') INTO l_goleta_month FROM DUAL;

        --DBMS_OUTPUT.put_line ('l_goleta_month: ' || l_goleta_month);

        --Get the Month for the passed in transaction date
        SELECT TO_CHAR (p_shipment_date, 'MON')
          INTO l_3pl_file_month
          FROM DUAL;

        --DBMS_OUTPUT.put_line ('l_3pl_file_month: ' || l_goleta_month);

        --Get the offset for the timezone
        l_offset     := get_offset (l_timezone);

        --DBMS_OUTPUT.put_line ('l_offset: ' || l_offset);

        /* SELECT - (SUM (gmt_deviation_hours) / 24)
           INTO l_offset
           FROM (SELECT -ht.gmt_deviation_hours AS gmt_deviation_hours
                   FROM apps.hz_timezones ht, apps.hz_timezones_tl htt
                  WHERE     htt.name = l_timezone
                        AND htt.language = 'US'
                        AND ht.timezone_id = htt.timezone_id
                 UNION ALL
                 SELECT gmt_deviation_hours
                   FROM apps.hz_timezones ht
                  WHERE timezone_id =
                           apps.fnd_profile.VALUE ('SERVER_TIMEZONE_ID'));*/

        --Get the month for the 3PL location applying offset to US time
        SELECT TO_CHAR (p_svr_date + l_offset, 'MON')
          INTO l_3pl_month
          FROM DUAL;

        --DBMS_OUTPUT.put_line ('l_3pl_month: ' || l_3pl_month);

        --3PL EOM Logic
        /**************************************
        Case 1
        Goleta Month = 3PL Month = 3PL Transaction Month => set transaction date to passed in value (no alteration needed)

        Case 2
        3PL Month != Goleta Month
        3PL in next GL period. We need to set the transaction date to the first of the next month (future month in Goleta)



        **************************************/

        IF l_3pl_month = l_goleta_month
        THEN
            --DBMS_OUTPUT.put_line ('Both Months are same..');

            IF l_3pl_month = l_3pl_file_month
            THEN
                --DBMS_OUTPUT.put_line ('Both 3PL Months are same..');
                d_return_date   := p_shipment_date;
            ELSE
                --DBMS_OUTPUT.put_line ('Both 3PL Months are NOT same..');

                /*select  to_char(round(sysdate+to_char(last_day(sysdate),'DD') - to_char(sysdate,'DD'),'MON')+(1/(24*60)),'MM/DD/YYYY HH:MI:SS AM')
                into l_return_date
                from dual;
                */
                --3PL local time and 3PL File times are different and so, converting this to 3PL local time
                SELECT ROUND (p_svr_date + l_offset, 'MON') + (1 / (24 * 60))
                  INTO d_return_date
                  FROM DUAL;
            END IF;                            -- End for 3PL file month check
        ELSE
            --DBMS_OUTPUT.put_line ('Both Months are NOT same..');

            d_return_date   :=
                get_first_of_next_month (p_svr_date) + (1 / (24 * 60));
        END IF;                            --End for 3PL local time zone check

        RETURN d_return_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            --DBMS_OUTPUT.put_line (SQLERRM);
            RETURN l_return_date;
            NULL;
    END;

    PROCEDURE process_txn_date_records (errbuf    OUT VARCHAR2,
                                        retcode   OUT VARCHAR2)
    IS
        CURSOR c_eligible_cursor IS
            SELECT alpha.*
              FROM (SELECT 'MTI' AS table_name, organization_id AS warehouse_id, transaction_interface_id record_id,
                           transaction_header_id GROUP_ID
                      FROM apps.mtl_transactions_interface
                     WHERE     ERROR_CODE IS NOT NULL
                           AND (error_explanation LIKE 'Transaction date cannot be a future date%' OR error_explanation LIKE 'No open period found with date entered%')
                    UNION ALL
                    SELECT 'RTI' AS table_name, rti.to_organization_id warehouse_id, rti.interface_transaction_id,
                           rti.GROUP_ID
                      FROM apps.rcv_transactions_interface rti, apps.po_interface_errors pie
                     WHERE     rti.processing_status_code = 'ERROR'
                           AND rti.GROUP_ID = pie.batch_id
                           AND UPPER (pie.error_message) LIKE
                                   '%OPEN%ACCOUNTING PERIOD%'
                    UNION ALL
                    SELECT h.message_name AS table_name, h.organization_id warehouse_id, h.osc_header_id,
                           TO_NUMBER (h.order_id)
                      FROM xxdo.XXDO_WMS_3PL_OSC_H h
                     WHERE     h.process_status = 'E'
                           AND h.error_message = 'Header failed to process.'
                           AND h.original_shipment_date IS NOT NULL) alpha;

        l_mti_records_cnt   NUMBER := 0;
        l_rti_records_cnt   NUMBER := 0;
        l_osc_records_cnt   NUMBER := 0;
        --l_tra_records_cnt    NUMBER :=0;
        --l_grn_records_cnt    NUMBER :=0;

        v_exec_statement    VARCHAR2 (1000);
    BEGIN
        --FND_FILE.put_line(FND_FILE.LOG,'process_txn_date_records Begining..');
        FOR c_eligible_records IN c_eligible_cursor
        LOOP
            FND_FILE.put_line (
                FND_FILE.LOG,
                'Record type..' || c_eligible_records.table_name);
            FND_FILE.put_line (FND_FILE.LOG,
                               'Record id..' || c_eligible_records.record_id);

            IF c_eligible_records.table_name = 'MTI'
            THEN
                l_mti_records_cnt   := l_mti_records_cnt + 1;

                --FND_FILE.put_line(FND_FILE.LOG,'Record count..'||l_mti_records_cnt);
                --FND_FILE.put_line(FND_FILE.LOG,'Record id value..'||c_eligible_records.record_id);
                BEGIN
                    UPDATE apps.mtl_transactions_interface
                       SET process_flag = 1, lock_flag = 2, transaction_mode = 3,
                           validation_required = 1, ERROR_CODE = NULL, error_explanation = NULL,
                           last_update_date = SYSDATE
                     WHERE transaction_interface_id =
                           c_eligible_records.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FND_FILE.put_line (
                            FND_FILE.LOG,
                            'Exception while updating MTI..' || SQLERRM);
                END;
            ELSIF c_eligible_records.table_name = 'RTI'
            THEN
                l_rti_records_cnt   := l_rti_records_cnt + 1;

                --FND_FILE.put_line(FND_FILE.LOG,'Record count..'||l_rti_records_cnt);
                --FND_FILE.put_line(FND_FILE.LOG,'Header id value..'||c_eligible_records.record_id);

                BEGIN
                    DELETE FROM apps.po_interface_errors
                          WHERE batch_id = c_eligible_records.GROUP_ID;

                    UPDATE apps.rcv_headers_interface
                       SET processing_status_code = 'PENDING', last_update_date = SYSDATE
                     WHERE GROUP_ID = c_eligible_records.GROUP_ID;

                    UPDATE apps.rcv_transactions_interface rti
                       SET processing_status_code = 'PENDING', transaction_status_code = 'PENDING', last_update_date = SYSDATE
                     WHERE GROUP_ID = c_eligible_records.GROUP_ID;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FND_FILE.put_line (
                            FND_FILE.LOG,
                            'Exception while updating RTI..' || SQLERRM);
                END;
            ELSIF c_eligible_records.table_name = 'HOSC'
            THEN
                l_osc_records_cnt   := l_osc_records_cnt + 1;

                --FND_FILE.put_line(FND_FILE.LOG,'Record count..'||l_osc_records_cnt);
                --FND_FILE.put_line(FND_FILE.LOG,'Header id value..'||c_eligible_records.record_id);
                --FND_FILE.put_line(FND_FILE.LOG,'Session id value..'||userenv('SESSIONID'));
                BEGIN
                    UPDATE xxdo.XXDO_WMS_3PL_OSC_L
                       SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
                     WHERE osc_header_id = c_eligible_records.record_id;

                    -- Update corresponding headers
                    UPDATE xxdo.XXDO_WMS_3PL_OSC_H -- Contains header data for LC data.
                       SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
                     WHERE osc_header_id = c_eligible_records.record_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FND_FILE.put_line (
                            FND_FILE.LOG,
                               'Exception while updating OSC Stage tables..'
                            || SQLERRM);
                END;
            /*  ELSIF c_eligible_records.PROCESS_NAME='HTRA' THEN
                  l_tra_records_cnt := l_tra_records_cnt+1;
                  BEGIN
                      update xxdo.XXDO_WMS_3PL_TRA_L
                      set     process_status = 'P'
                              ,error_message = null
                              ,processing_session_id = userenv('SESSIONID')
                      where tra_header_id = c_eligible_records.header_id;

                      -- Update corresponding headers
                      update xxdo.XXDO_WMS_3PL_TRA_H -- Contains header data for LC data.
                      set     process_status = 'P'
                              ,error_message = null
                              ,processing_session_id = userenv('SESSIONID')
                      where tra_header_id = c_eligible_records.header_id;

                  EXCEPTION
                      WHEN OTHERS THEN
                      FND_FILE.put_line(FND_FILE.LOG,'Exception while updating OSC Stage tables..'||SQLERRM);
                  END;

              ELSIF c_eligible_records.PROCESS_NAME='HGRN' THEN
                  l_grn_records_cnt := l_grn_records_cnt+1;
                  BEGIN
                      update xxdo.XXDO_WMS_3PL_GRN_L
                      set     process_status = 'P'
                              ,error_message = null
                              ,processing_session_id = userenv('SESSIONID')
                      where grn_header_id = c_eligible_records.header_id;

                      -- Update corresponding headers
                      update xxdo.XXDO_WMS_3PL_GRN_H -- Contains header data for LC data.
                      set     process_status = 'P'
                              ,error_message = null
                              ,processing_session_id = userenv('SESSIONID')
                      where grn_header_id = c_eligible_records.header_id;

                  EXCEPTION
                      WHEN OTHERS THEN
                      FND_FILE.put_line(FND_FILE.LOG,'Exception while updating OSC Stage tables..'||SQLERRM);
                  END;   */
            END IF;                                --End for 3PL Process check
        END LOOP;                                 --End for c_eligible_records

        IF l_mti_records_cnt > 0 OR l_rti_records_cnt > 0
        THEN
            BEGIN
                FND_FILE.put_line (FND_FILE.LOG, 'Executing commit...');
                COMMIT;
                l_mti_records_cnt   := 0;
                l_rti_records_cnt   := 0;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.put_line (
                        FND_FILE.LOG,
                        'Exception while executing commit..' || SQLERRM);
                    l_mti_records_cnt   := 0;
                    l_rti_records_cnt   := 0;
            END;
        END IF;                                    --End for l_mti_records_cnt

        IF l_osc_records_cnt > 0
        THEN
            BEGIN
                --FND_FILE.put_line(FND_FILE.LOG,'Executing LC procedure...');
                --FND_FILE.put_line(FND_FILE.LOG,'Total No. of OSC Records to execute...'||l_osc_records_cnt);
                v_exec_statement    :=
                    'begin apps.XXDO_WMS_3PL_INTERFACE.PROCESS_LOAD_CONFIRMATION; end;';

                --FND_FILE.put_line(FND_FILE.LOG,'Before executing immediate...'||v_exec_statement);
                EXECUTE IMMEDIATE (v_exec_statement);

                --FND_FILE.put_line(FND_FILE.LOG,'After executing immediate...');
                COMMIT;
                l_osc_records_cnt   := 0;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.put_line (
                        FND_FILE.LOG,
                        'Exception while executing LC Procedure..' || SQLERRM);
                    l_osc_records_cnt   := 0;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.put_line (FND_FILE.LOG,
                               'Unknown Exception..' || SQLERRM);
            errbuf    := SQLERRM;
            retcode   := '2';
    END;                                                       --Procedure END
END XXDO_INT_WMS_UTIL;
/


GRANT EXECUTE ON APPS.XXDO_INT_WMS_UTIL TO XXDO
/
