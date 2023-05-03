--
-- XXDO_LPN_PUB  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_LPN_PUB"
AS
    /******************************************************************************/
    /* Name       : Package Body XXDO_LPN_PUB
    /* Created by : Infosys Ltd.(Karthik Kumar K S)
    /* Created On : 6/9/2016
    /* Description: Package to bundle all custom built functionality related to LPN
    /*              in WMS Org.
    /******************************************************************************/
    /**/
    /******************************************************************************/
    /* Name         : MASS_LPN_UNLOAD_PRC
    /* Description  : Procedure to Mass break down  LPN's from parent LPN
    /******************************************************************************/
    PROCEDURE MASS_LPN_UNLOAD_PRC (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, p_org_id IN NUMBER
                                   , p_lpn_id IN NUMBER)
    AS
        --Cursor to get LPN information with context
        CURSOR cur_get_lpn_status (c_lpn_id IN NUMBER)
        IS
            SELECT lpn.lpn_id, lpn.parent_lpn_id, lpn.LOCATOR_ID,
                   lpn.LPN_CONTEXT, lpn.LICENSE_PLATE_NUMBER, lpn.ORGANIZATION_ID,
                   lpn.SUBINVENTORY_CODE
              FROM wms_license_plate_numbers lpn
             WHERE lpn.lpn_id = c_lpn_id;

        --Cursor to get Child LPN's information with context
        CURSOR cur_get_child_lpn (c_parent_lpn_id IN NUMBER)
        IS
            SELECT lpn.lpn_id, lpn.parent_lpn_id, lpn.LOCATOR_ID,
                   lpn.LPN_CONTEXT, lpn.LICENSE_PLATE_NUMBER, lpn.ORGANIZATION_ID,
                   lpn.SUBINVENTORY_CODE
              FROM wms_license_plate_numbers lpn
             WHERE lpn.parent_lpn_id = c_parent_lpn_id;

        TYPE t_child_lpn_tab IS TABLE OF cur_get_child_lpn%ROWTYPE
            INDEX BY PLS_INTEGER;

        t_child_lpn_rec   t_child_lpn_tab;
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
        x_return_status   VARCHAR2 (1);
        l_msgdata         VARCHAR2 (2000);
        l_fetch_limit     NUMBER := 1000;
        l_lpn_id          NUMBER;
        i_index           NUMBER := 0;
        e_api_error       EXCEPTION;
        e_invalid_error   EXCEPTION;
    BEGIN
        /*Start process*/
        fnd_file.put_line (fnd_file.LOG, LPAD ('+', 78, '+'));
        fnd_file.put_line (fnd_file.LOG, ' Start of Mass LPN Unload process');
        fnd_file.put_line (fnd_file.LOG, ' Parameters');
        fnd_file.put_line (fnd_file.LOG, ' Organization ID =' || p_org_id);
        fnd_file.put_line (fnd_file.LOG, ' LPN ID =' || p_lpn_id);
        fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
        /* Inititalize Error code and errbuff*/
        p_out_error_code   := 0;
        p_out_error_buff   := NULL;
        l_lpn_id           := 0;

        /*End of initialization*/
        --
        /*Get given LPN ID information*/
        fnd_file.put_line (fnd_file.LOG, ' Start validation of input LPN #');

        FOR rec_get_lpn_status IN cur_get_lpn_status (p_lpn_id)
        LOOP
            --Get LPN ID
            l_lpn_id   := rec_get_lpn_status.lpn_id;

            --Validate if given lpn is parent LPN or not
            IF NVL (rec_get_lpn_status.parent_lpn_id,
                    rec_get_lpn_status.lpn_id) !=
               rec_get_lpn_status.lpn_id
            THEN
                l_msgdata   :=
                       'ERROR: LPN Number '
                    || rec_get_lpn_status.LICENSE_PLATE_NUMBER
                    || ' is not parent LPN';
                RAISE e_invalid_error;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'LPN Number '
                    || rec_get_lpn_status.LICENSE_PLATE_NUMBER
                    || ' is parent LPN');
            END IF;

            --Validate if LPN have locator or not
            IF rec_get_lpn_status.LOCATOR_ID IS NULL
            THEN
                l_msgdata   :=
                       'ERROR: LPN Number '
                    || rec_get_lpn_status.LICENSE_PLATE_NUMBER
                    || '; Locator is null';
                RAISE e_invalid_error;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'LPN Number '
                    || rec_get_lpn_status.LICENSE_PLATE_NUMBER
                    || '; Locator is availabe');
            END IF;

            -- Validate if LPN
            IF rec_get_lpn_status.lpn_context != 11
            THEN
                l_msgdata   :=
                       'ERROR: LPN Number '
                    || rec_get_lpn_status.LICENSE_PLATE_NUMBER
                    || '; LPN context is not 11(Picked)';
                RAISE e_invalid_error;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'LPN Number '
                    || rec_get_lpn_status.LICENSE_PLATE_NUMBER
                    || '; LPN context is '
                    || rec_get_lpn_status.lpn_context);
            END IF;
        END LOOP;                       --close cursor cur_get_lpn_status loop

        /*IF LPN is not found*/
        IF l_lpn_id = 0
        THEN
            l_msgdata   := 'ERROR: Invalid LPN Number; Unable to find LPN';
            RAISE e_invalid_error;
        END IF;

        /*End of validation*/
        fnd_file.put_line (fnd_file.LOG, ' End validation of input LPN #');
        fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
        --Open and fetch fetch Child LPN Records
        fnd_file.put_line (
            fnd_file.LOG,
            ' Start fetching child LPN and status before break down');
        fnd_file.put_line (
            fnd_file.LOG,
               RPAD ('LICENSE_PLATE_NUMBER', 30, ' ')
            || RPAD ('LPN CONTEXT', 15, ' ')
            || RPAD ('PARENT LPN ID', 15, ' '));

        /*Start fetching child LPN Information from table*/
        FOR rec_get_child_lpn IN cur_get_child_lpn (l_lpn_id)
        LOOP
            FOR rec_get_lpn_status
                IN cur_get_lpn_status (rec_get_child_lpn.lpn_id)
            LOOP
                i_index                     := i_index + 1;
                fnd_file.put_line (
                    fnd_file.LOG,
                       RPAD (rec_get_lpn_status.LICENSE_PLATE_NUMBER,
                             30,
                             ' ')
                    || RPAD (rec_get_lpn_status.LPN_context, 15, ' ')
                    || RPAD (rec_get_lpn_status.parent_lpn_id, 15, ' '));
                t_child_lpn_rec (i_index)   := rec_get_lpn_status;
            END LOOP;                   --close cursor cur_get_lpn_status loop
        END LOOP;                              --close table t_ar_inv_rec loop

        fnd_file.put_line (
            fnd_file.LOG,
            ' End fetching child LPN and status before break down');
        fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
        /*End of fetching child LPN Information from table*/
        --
        fnd_file.put_line (fnd_file.LOG,
                           ' Calling API WMS_Container_PUB.Break_Down_LPN ');
        /*Calling WMS API to break down LPN*/
        WMS_Container_PUB.Break_Down_LPN (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_false,
            p_commit             => fnd_api.g_true,
            x_return_status      => x_return_status,
            x_msg_count          => x_msg_count,
            x_msg_data           => x_msg_data,
            p_organization_id    => p_org_id,
            p_outermost_lpn_id   => l_lpn_id);
        fnd_file.put_line (fnd_file.LOG,
                           'API WMS_Container_PUB.Break_Down_LPN call END');
        fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
        /*End of API call*/
        --
        /*Get API return message*/
        fnd_file.put_line (
            fnd_file.LOG,
            'API WMS_Container_PUB.Break_Down_LPN Message and return status');

        IF x_msg_count = 1
        THEN
            l_msgdata   := x_msg_data;
        ELSE
            FOR i IN 1 .. x_msg_count
            LOOP
                l_msgdata   :=
                    SUBSTR (
                           l_msgdata
                        || ' | '
                        || SUBSTR (
                               fnd_msg_pub.get (x_msg_count - i + 1, 'F'),
                               0,
                               200),
                        1,
                        2000);
            END LOOP;
        END IF;                                                    --msg count

        --
        /*Get API return status and select appropriate exception for error*/
        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Successfully break down LPN');
            fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
            fnd_file.put_line (
                fnd_file.LOG,
                ' Start of fetching child LPN''s and status after break down');
            /*Start of child LPN Information*/
            fnd_file.put_line (
                fnd_file.LOG,
                   RPAD ('LICENSE_PLATE_NUMBER', 30, ' ')
                || RPAD ('LPN CONTEXT', 15, ' ')
                || RPAD ('PARENT LPN ID', 15, ' '));

            FOR i IN t_child_lpn_rec.FIRST .. t_child_lpn_rec.LAST
            LOOP
                FOR rec_get_lpn_status
                    IN cur_get_lpn_status (t_child_lpn_rec (i).lpn_id)
                LOOP
                    fnd_file.put_line (
                        fnd_file.LOG,
                           RPAD (rec_get_lpn_status.LICENSE_PLATE_NUMBER,
                                 30,
                                 ' ')
                        || RPAD (rec_get_lpn_status.LPN_context, 15, ' ')
                        || RPAD (rec_get_lpn_status.parent_lpn_id, 15, ' '));
                END LOOP;               --close cursor cur_get_lpn_status loop
            END LOOP;                          --close table t_ar_inv_rec loop

            fnd_file.put_line (
                fnd_file.LOG,
                ' End of fetching child LPN''s and status after break down');
            fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
        ELSE
            --fnd_file.put_line ( fnd_file.LOG,x_return_status||': '||l_msgdata);
            RAISE e_api_error;
        END IF;                                                --return status

        /*end process*/
        fnd_file.put_line (fnd_file.LOG, ' End of Mass LPN Unload process');
        fnd_file.put_line (fnd_file.LOG, LPAD ('+', 78, '+'));
    EXCEPTION
        WHEN e_invalid_error
        THEN
            p_out_error_code   := 2;
            p_out_error_buff   := l_msgdata;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Procedure - XXDO_LPN_PUB.MASS_LPN_UNLOAD_PRC: Validation Error -  '
                || l_msgdata);
        WHEN e_api_error
        THEN
            p_out_error_code   := 2;
            p_out_error_buff   := l_msgdata;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Procedure - XXDO_LPN_PUB.MASS_LPN_UNLOAD_PRC: API Error -  '
                || x_return_status
                || '-'
                || l_msgdata);
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            p_out_error_buff   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Procedure - XXDO_LPN_PUB.MASS_LPN_UNLOAD_PRC: Other Error -  '
                || SQLERRM);
    END MASS_LPN_UNLOAD_PRC;

    /******************************************************************************/
    /* Name         : UNLOAD_LPNS_FROM_DOCK
    /* Description  : Procedure to unload LPN's from Dock Door
    /******************************************************************************/
    PROCEDURE UNLOAD_LPNS_FROM_DOCK (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, p_org_id IN NUMBER
                                     , p_delv_id IN NUMBER)
    AS
        /*Define cursors*/
        CURSOR cur_dockdoor_lpns IS
            SELECT DISTINCT wlpn.lpn_id
              FROM apps.wms_license_plate_numbers wlpn, wms.wms_shipping_transaction_temp wstt
             WHERE     wlpn.lpn_context = 9
                   AND wlpn.lpn_id = wstt.outermost_lpn_id
                   AND wlpn.organization_id = p_org_id
                   AND wstt.delivery_id = p_delv_id;

        /*Define variables*/
        x_error_code    NUMBER;
        l_debug_value   NUMBER;
        l_prf_stat      BOOLEAN;
        e_api_failure   EXCEPTION;
    BEGIN
        /*Start process*/
        fnd_file.put_line (fnd_file.LOG, LPAD ('+', 78, '+'));
        fnd_file.put_line (fnd_file.LOG, ' Start of Unload LPN process');
        fnd_file.put_line (fnd_file.LOG, ' Parameters');
        fnd_file.put_line (fnd_file.LOG, ' Organization ID =' || p_org_id);
        fnd_file.put_line (fnd_file.LOG, ' Delivery Name =' || p_delv_id);
        fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));

        /* Inititalize Error code and errbuff*/
        p_out_error_buff   := NULL;
        p_out_error_code   := 0;

        /* End of Inititalize Error code and errbuff*/

        /*get debug flag value */
        BEGIN
            SELECT NVL (FND_PROFILE.VALUE ('INV_DEBUG_TRACE'), 0)
              INTO l_debug_value
              FROM DUAL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_debug_value   := 0;
            WHEN OTHERS
            THEN
                l_debug_value   := 0;
        END;

        /*End of get debug flag*/

        /**Set debug flag*/
        IF l_debug_value != 1
        THEN
            l_prf_stat   := fnd_profile.SAVE ('INV_DEBUG_TRACE', 1, 'SITE');

            IF l_prf_stat
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Profile INV_DEBUG_TRACE value 1 - Updated');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Profile INV_DEBUG_TRACE value 1- Update failed');
            END IF;
        END IF;

        COMMIT;

        /*End of Set debug flag*/

        /*Open and fetch cursor record for given Delivery ID*/
        FOR rec_dockdoor_lpns IN cur_dockdoor_lpns
        LOOP
            fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
            fnd_file.put_line (
                fnd_file.LOG,
                'Call API to Unload LPN -' || rec_dockdoor_lpns.lpn_id);

            WMS_SHIPPING_TRANSACTION_PUB.lpn_unload (
                p_organization_id    => p_org_id,
                p_outermost_lpn_id   => rec_dockdoor_lpns.lpn_id,
                x_error_code         => x_error_code);

            --Check for error code and raise exception
            IF x_error_code != 0
            THEN
                RAISE e_api_failure;
            END IF;

            fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
        END LOOP;

        /*close cursor record for given Delivery ID*/

        /*Reset debug flag to its former value*/
        IF l_debug_value != 1
        THEN
            l_prf_stat   :=
                fnd_profile.SAVE ('INV_DEBUG_TRACE', l_debug_value, 'SITE');

            IF l_prf_stat
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Reset Profile INV_DEBUG_TRACE value '
                    || l_debug_value
                    || ' - Updated');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Reset Profile INV_DEBUG_TRACE value '
                    || l_debug_value
                    || ' - Update failed');
            END IF;
        END IF;

        fnd_file.put_line (fnd_file.LOG, LPAD ('-', 78, '-'));
        fnd_file.put_line (fnd_file.LOG, ' End of Unload LPN process');
        fnd_file.put_line (fnd_file.LOG, LPAD ('+', 78, '+'));
    EXCEPTION
        WHEN e_api_failure
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error: API WMS_SHIPPING_TRANSACTION_PUB.lpn_unload failed to unlaod LPNS');
            p_out_error_buff   := 'API Error';
            p_out_error_code   := 2;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Procedure - XXDO_LPN_PUB.UNLOAD_LPNS_FROM_DOCK: Other Error -  '
                || SQLERRM);
            p_out_error_buff   := SQLERRM;
            p_out_error_code   := 2;
    END UNLOAD_LPNS_FROM_DOCK;
END XXDO_LPN_PUB;
/
