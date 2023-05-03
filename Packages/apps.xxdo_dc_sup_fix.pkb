--
-- XXDO_DC_SUP_FIX  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_DC_SUP_FIX"
AS
    /******************************************************************************/
    /* Name       : Package XXDO_DC_SUP_FIX
    /* Created by : Infosys Ltd
    /* Created On : 8/19/2016
    /* Description: Package to bundle all data fix related to LPN in WMS Org.
    /******************************************************************************/
    /**/
    /******************************************************************************/
    /* Name         : WRITE_LOG
    /* Description  : Procedure to write log
    /******************************************************************************/
    PROCEDURE WRITE_LOG (P_MSG IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, P_MSG);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Procedure - XXDO_DC_SUP_FIX.WRITE_LOG: Other Error -  '
                || SQLERRM);
    END WRITE_LOG;

    /******************************************************************************/
    /* Name         : INSERT_AUDIT
    /* Description  : Procedure to record changes
    /******************************************************************************/
    PROCEDURE INSERT_AUDIT (p_out_error_buff   OUT VARCHAR2,
                            p_out_error_code   OUT NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_rec_exists   NUMBER;
    BEGIN
        /* Inititalize Error code and errbuff*/
        p_out_error_code   := 0;
        p_out_error_buff   := NULL;
        /*End of initialization*/
        l_rec_exists       := 0;

        SELECT COUNT (1)
          INTO l_rec_exists
          FROM XXDO_DC_SUPPORT_FIX_AUDIT
         WHERE request_id = g_audit_rec.REQUEST_ID;

        IF l_rec_exists = 0
        THEN
            WRITE_LOG (
                'Insert Audit records into XXDO_DC_SUPPORT_FIX_AUDIT ');

            INSERT INTO XXDO_DC_SUPPORT_FIX_AUDIT
                     VALUES (g_audit_rec.REQUEST_ID,
                             g_audit_rec.INCIDENT_NUM,
                             g_audit_rec.TABLE_NAME,
                             g_audit_rec.ID_COLUMN,
                             g_audit_rec.ID_COLUMN_VALUE,
                             g_audit_rec.STATUS,
                             g_audit_rec.OLD_SUBINV_CODE,
                             g_audit_rec.NEW_SUBINV_CODE,
                             g_audit_rec.OLD_LOCATOR_ID,
                             g_audit_rec.NEW_LOCATOR_ID,
                             g_audit_rec.OLD_LPN_CONTEXT,
                             g_audit_rec.NEW_LPN_CONTEXT,
                             g_audit_rec.OLD_PARENT_LPN_ID,
                             g_audit_rec.NEW_PARENT_LPN_ID,
                             g_audit_rec.OLD_OUTER_LPN_ID,
                             g_audit_rec.NEW_OUTER_LPN_ID,
                             g_audit_rec.OLD_MMTT_LPN_ID,
                             g_audit_rec.NEW_MMTT_LPN_ID,
                             g_audit_rec.OLD_MMTT_TRANS_LPN_ID,
                             g_audit_rec.NEW_MMTT_TRANS_LPN_ID,
                             g_audit_rec.DELETE_WSTT_COUNT,
                             g_audit_rec.COMMENTS,
                             g_audit_rec.ATTRIBUTE1,
                             g_audit_rec.ATTRIBUTE2,
                             g_audit_rec.ATTRIBUTE3,
                             g_audit_rec.ATTRIBUTE4,
                             g_audit_rec.ATTRIBUTE5,
                             SYSDATE,
                             g_audit_rec.CREATED_BY,
                             SYSDATE,
                             g_audit_rec.LAST_UPDATED_BY,
                             g_audit_rec.LAST_UPDATE_LOGIN);
        ELSE
            WRITE_LOG (
                   'Update Audit records into XXDO_DC_SUPPORT_FIX_AUDIT for request id '
                || g_audit_rec.REQUEST_ID);

            UPDATE XXDO_DC_SUPPORT_FIX_AUDIT
               SET STATUS = g_audit_rec.STATUS, ID_COLUMN = g_audit_rec.ID_COLUMN, OLD_SUBINV_CODE = g_audit_rec.OLD_SUBINV_CODE,
                   NEW_SUBINV_CODE = g_audit_rec.NEW_SUBINV_CODE, OLD_LOCATOR_ID = g_audit_rec.OLD_LOCATOR_ID, NEW_LOCATOR_ID = g_audit_rec.NEW_LOCATOR_ID,
                   OLD_LPN_CONTEXT = g_audit_rec.OLD_LPN_CONTEXT, NEW_LPN_CONTEXT = g_audit_rec.NEW_LPN_CONTEXT, OLD_PARENT_LPN_ID = g_audit_rec.OLD_PARENT_LPN_ID,
                   NEW_PARENT_LPN_ID = g_audit_rec.NEW_PARENT_LPN_ID, OLD_OUTER_LPN_ID = g_audit_rec.OLD_OUTER_LPN_ID, NEW_OUTER_LPN_ID = g_audit_rec.NEW_OUTER_LPN_ID,
                   OLD_MMTT_LPN_ID = g_audit_rec.OLD_MMTT_LPN_ID, NEW_MMTT_LPN_ID = g_audit_rec.NEW_MMTT_LPN_ID, OLD_MMTT_TRANS_LPN_ID = g_audit_rec.OLD_MMTT_TRANS_LPN_ID,
                   NEW_MMTT_TRANS_LPN_ID = g_audit_rec.NEW_MMTT_TRANS_LPN_ID, DELETE_WSTT_COUNT = g_audit_rec.DELETE_WSTT_COUNT, COMMENTS = g_audit_rec.COMMENTS,
                   ATTRIBUTE1 = g_audit_rec.ATTRIBUTE1, ATTRIBUTE2 = g_audit_rec.ATTRIBUTE2, ATTRIBUTE3 = g_audit_rec.ATTRIBUTE3,
                   ATTRIBUTE4 = g_audit_rec.ATTRIBUTE4, ATTRIBUTE5 = g_audit_rec.ATTRIBUTE5, LAST_UPDATE_DATE = SYSDATE,
                   LAST_UPDATED_BY = g_audit_rec.LAST_UPDATED_BY, LAST_UPDATE_LOGIN = g_audit_rec.LAST_UPDATE_LOGIN
             WHERE request_id = g_audit_rec.REQUEST_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.INSERT_AUDIT: Other Error -  '
                || SQLERRM);
            RAISE;
    END INSERT_AUDIT;

    /******************************************************************************/
    /* Name         : LPN_UPDATE_FIX
    /* Description  : Procedure to fix WMS_LICENSE_PLATE_NUMBERS related records
    /******************************************************************************/
    PROCEDURE LPN_UPDATE_FIX (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ID IN NUMBER, P_ORG_ID IN NUMBER, P_SUBINV IN VARCHAR2, P_LOC_ID IN NUMBER
                              , P_LPN_CONTEXT IN NUMBER, P_IN_PARENT_LPN IN NUMBER, P_IN_OUTERMOST_LPN IN NUMBER)
    IS
        l_old_sub       VARCHAR2 (30);
        l_lpn_num       VARCHAR2 (30);
        l_old_locator   NUMBER;
        l_old_lpn_con   NUMBER;
        l_old_parent    NUMBER;
        l_old_out_lpn   NUMBER;
        l_errm          VARCHAR2 (500);
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG (
            ' Start of Deckers DC Operations Support Fix - WMS_LICENSE_PLATE_NUMBERS - UPDATE FIX');
        WRITE_LOG (' Parameters');
        WRITE_LOG (' LPN ID         =' || P_ID);
        WRITE_LOG (' Organization ID=' || P_ORG_ID);
        WRITE_LOG (' Sub Inventory  =' || P_SUBINV);
        WRITE_LOG (' Locator ID     =' || P_LOC_ID);
        WRITE_LOG (' LPN Context    =' || P_LPN_CONTEXT);
        WRITE_LOG (' Parent LPN     =' || P_IN_PARENT_LPN);
        WRITE_LOG (' Outermost LPN  =' || P_IN_OUTERMOST_LPN);

        /* Inititalize variables*/
        p_out_error_code                := 0;
        p_out_error_buff                := NULL;
        g_audit_rec.ID_COLUMN           := 'LPN_ID';

        /*End of initialization*/
        --
        --
        BEGIN
            SELECT LICENSE_PLATE_NUMBER, SUBINVENTORY_CODE, LOCATOR_ID,
                   LPN_CONTEXT, PARENT_LPN_ID, OUTERMOST_LPN_ID
              INTO l_lpn_num, l_old_sub, l_old_locator, l_old_lpn_con,
                            l_old_parent, l_old_out_lpn
              FROM apps.wms_license_plate_numbers
             WHERE lpn_id = P_ID AND organization_id = P_ORG_ID;

            WRITE_LOG (
                   'Before update of LPN# '
                || l_lpn_num
                || ' Context '
                || l_old_lpn_con
                || ' Subinvenory code '
                || l_old_sub
                || ' locator ID '
                || l_old_locator
                || ' Parent LPN ID '
                || l_old_parent
                || ' Outermost LPN ID '
                || l_old_out_lpn);
        EXCEPTION
            WHEN OTHERS
            THEN
                WRITE_LOG (SQLERRM);
                WRITE_LOG (' No LPN records found for given id = ' || P_ID);
                l_errm   := 'No LPN records found for given id = ' || P_ID;
                RAISE g_invalid_excpn;
        END;

        g_audit_rec.STATUS              := 'INPROCESS';
        g_audit_rec.OLD_SUBINV_CODE     := l_old_sub;
        g_audit_rec.OLD_LOCATOR_ID      := l_old_locator;
        g_audit_rec.OLD_LPN_CONTEXT     := l_old_lpn_con;
        g_audit_rec.OLD_OUTER_LPN_ID    := l_old_out_lpn;
        g_audit_rec.OLD_PARENT_LPN_ID   := l_old_parent;

        IF l_old_lpn_con = 9 AND P_LPN_CONTEXT != 9
        THEN
            BEGIN
                WRITE_LOG (
                       ' Archive WMS_SHIPPING_TRANSACTION_TEMP record for LPN ID = '
                    || P_ID);

                INSERT INTO XXDO_WMS_SHIP_TRAN_TEMP_BACKUP
                    (SELECT *
                       FROM WMS.WMS_SHIPPING_TRANSACTION_TEMP
                      WHERE (PARENT_LPN_ID = P_ID OR OUTERMOST_LPN_ID = P_ID));

                g_audit_rec.ATTRIBUTE1          :=
                       'BACKUP OF WSTT IN XXDO_WMS_SHIP_TRAN_TEMP_BACKUP - '
                    || SQL%ROWCOUNT;
                WRITE_LOG (
                       ' Delete WMS_SHIPPING_TRANSACTION_TEMP record for LPN ID = '
                    || P_ID);

                DELETE FROM WMS.WMS_SHIPPING_TRANSACTION_TEMP
                      WHERE (PARENT_LPN_ID = P_ID OR OUTERMOST_LPN_ID = P_ID);

                g_audit_rec.DELETE_WSTT_COUNT   := SQL%ROWCOUNT;
                g_audit_rec.ATTRIBUTE2          :=
                       'DELETED FROM WMS_SHIPPING_TRANSACTION_TEMP - '
                    || SQL%ROWCOUNT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    WRITE_LOG (SQLERRM);
                    WRITE_LOG (
                           ' Unable to archive WMS_SHIPPING_TRANSACTION_TEMP record for LPN ID = '
                        || P_ID);
                    l_errm   :=
                           ' Unable to archive WMS_SHIPPING_TRANSACTION_TEMP record for LPN ID = '
                        || P_ID;
                    RAISE g_invalid_excpn;
            END;
        END IF;

        --
        --
        UPDATE apps.wms_license_plate_numbers
           SET lpn_context = NVL (P_LPN_CONTEXT, lpn_context), locator_id = NVL (P_LOC_ID, LOCATOR_ID), subinventory_code = NVL (P_SUBINV, SUBINVENTORY_CODE),
               PARENT_LPN_ID = DECODE (P_IN_PARENT_LPN, -1, NULL, NVL (P_IN_PARENT_LPN, PARENT_LPN_ID)), outermost_lpn_id = DECODE (P_IN_OUTERMOST_LPN, -1, NULL, NVL (P_IN_OUTERMOST_LPN, outermost_lpn_id)), LAST_UPDATED_BY = FND_GLOBAL.user_id,
               LAST_UPDATE_DATE = SYSDATE
         WHERE lpn_id = P_ID;


        SELECT LICENSE_PLATE_NUMBER, SUBINVENTORY_CODE, LOCATOR_ID,
               LPN_CONTEXT, PARENT_LPN_ID, OUTERMOST_LPN_ID
          INTO l_lpn_num, g_audit_rec.NEW_SUBINV_CODE, g_audit_rec.NEW_LOCATOR_ID, g_audit_rec.NEW_LPN_CONTEXT,
                        g_audit_rec.NEW_PARENT_LPN_ID, g_audit_rec.NEW_OUTER_LPN_ID
          FROM apps.wms_license_plate_numbers
         WHERE lpn_id = P_ID;

        WRITE_LOG (
               'After update of LPN# '
            || l_lpn_num
            || ' Context '
            || g_audit_rec.NEW_LPN_CONTEXT
            || ' Subinvenory code '
            || g_audit_rec.NEW_SUBINV_CODE
            || ' locator ID '
            || g_audit_rec.NEW_LOCATOR_ID
            || ' Parent LPN ID '
            || g_audit_rec.NEW_PARENT_LPN_ID
            || ' Outermost LPN ID '
            || g_audit_rec.NEW_OUTER_LPN_ID);

        --
        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN g_invalid_excpn
        THEN
            p_out_error_code   := 2;
            g_err_buf          := l_errm;
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.LPN_UPDATE_FIX: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
    END LPN_UPDATE_FIX;

    /******************************************************************************/
    /* Name         : MOQD_UPDATE_FIX
    /* Description  : Procedure to fix MTL_ONHAND_QUANTITIES_DETAIL related records
    /******************************************************************************/
    PROCEDURE MOQD_UPDATE_FIX (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ID IN NUMBER, P_ORG_ID IN NUMBER, P_SUBINV IN VARCHAR2, P_LOC_ID IN NUMBER
                               , P_IN_LPN IN NUMBER)
    IS
        l_old_sub       VARCHAR2 (30);
        l_old_locator   NUMBER;
        l_lpn_id        NUMBER;
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG (
            ' Start of Deckers DC Operations Support Fix - MTL_ONHAND_QUANTITIES_DETAIL - UPDATE FIX');
        WRITE_LOG (' Parameters');
        WRITE_LOG (' Onhand Quantities ID   =' || P_ID);
        WRITE_LOG (' Organization ID        =' || P_ORG_ID);
        WRITE_LOG (' Sub Inventory          =' || P_SUBINV);
        WRITE_LOG (' Locator ID             =' || P_LOC_ID);
        WRITE_LOG (' LPN                    =' || P_IN_LPN);

        /* Inititalize variables*/
        p_out_error_code              := 0;
        p_out_error_buff              := NULL;
        g_audit_rec.ID_COLUMN         := 'ONHAND_QUANTITIES_ID';

        /*End of initialization*/
        --
        --
        BEGIN
            SELECT subinventory_code, locator_id, lpn_id
              INTO l_old_sub, l_old_locator, l_lpn_id
              FROM apps.mtl_onhand_quantities_detail
             WHERE ONHAND_QUANTITIES_ID = P_ID AND organization_id = P_ORG_ID;

            WRITE_LOG (
                   'Before update Subinvenory code '
                || l_old_sub
                || ' locator ID '
                || l_old_locator
                || ' LPN ID'
                || l_lpn_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                WRITE_LOG (SQLERRM);
                WRITE_LOG (
                       ' No Onhand quantities records found for given id = '
                    || P_ID);
                RAISE g_invalid_excpn;
        END;

        g_audit_rec.STATUS            := 'INPROCESS';
        g_audit_rec.OLD_SUBINV_CODE   := l_old_sub;
        g_audit_rec.OLD_LOCATOR_ID    := l_old_locator;
        g_audit_rec.OLD_MMTT_LPN_ID   := l_lpn_id;

        --
        UPDATE apps.mtl_onhand_quantities_detail
           SET locator_id = NVL (P_LOC_ID, LOCATOR_ID), subinventory_code = NVL (P_SUBINV, SUBINVENTORY_CODE), lpn_id = DECODE (P_IN_LPN, -1, NULL, NVL (P_IN_LPN, lpn_id)),
               LAST_UPDATED_BY = FND_GLOBAL.user_id, LAST_UPDATE_DATE = SYSDATE
         WHERE ONHAND_QUANTITIES_ID = P_ID;


        SELECT subinventory_code, locator_id, lpn_id
          INTO g_audit_rec.NEW_SUBINV_CODE, g_audit_rec.NEW_LOCATOR_ID, g_audit_rec.NEW_MMTT_LPN_ID
          FROM apps.mtl_onhand_quantities_detail
         WHERE ONHAND_QUANTITIES_ID = P_ID;

        WRITE_LOG (
               'After update Subinvenory code '
            || g_audit_rec.NEW_SUBINV_CODE
            || ' locator ID '
            || g_audit_rec.NEW_LOCATOR_ID
            || ' LPN ID'
            || g_audit_rec.NEW_MMTT_LPN_ID);

        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN g_invalid_excpn
        THEN
            p_out_error_code   := 2;
            g_err_buf          :=
                ' No Onhand quantities records found for given id = ' || P_ID;
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.MOQD_UPDATE_FIX: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
    END MOQD_UPDATE_FIX;

    /******************************************************************************/
    /* Name         : MMTT_UPDATE_FIX
    /* Description  : Procedure to fix MTL_MATERIAL_TRANSATIONS_TEMP related records
    /******************************************************************************/
    PROCEDURE MMTT_UPDATE_FIX (p_out_error_buff      OUT VARCHAR2,
                               p_out_error_code      OUT NUMBER,
                               P_ID               IN     NUMBER,
                               P_ORG_ID           IN     NUMBER,
                               P_SUBINV           IN     VARCHAR2,
                               P_LOC_ID           IN     NUMBER,
                               P_IN_LPN           IN     NUMBER,
                               P_TRANSFER_LPN     IN     NUMBER)
    IS
        l_old_sub       VARCHAR2 (30);
        l_old_locator   NUMBER;
        l_lpn_id        NUMBER;
        l_tran_lpn_id   NUMBER;
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG (
            ' Start of Deckers DC Operations Support Fix - MTL_MATERIAL_TRANSACTIONS_TEMP - UPDATE FIX');
        WRITE_LOG (' Parameters');
        WRITE_LOG (' Transaction Temp ID  =' || P_ID);
        WRITE_LOG (' Organization ID      =' || P_ORG_ID);
        WRITE_LOG (' Sub Inventory        =' || P_SUBINV);
        WRITE_LOG (' Locator ID           =' || P_LOC_ID);
        WRITE_LOG (' LPN                  =' || P_IN_LPN);
        WRITE_LOG (' Transfer LPN         =' || P_TRANSFER_LPN);

        /* Inititalize variables*/
        p_out_error_code                    := 0;
        p_out_error_buff                    := NULL;
        g_audit_rec.ID_COLUMN               := 'TRANSACTION_TEMP_ID';

        /*End of initialization*/
        --
        --
        BEGIN
            SELECT SUBINVENTORY_CODE, LOCATOR_ID, LPN_ID,
                   TRANSFER_LPN_ID
              INTO l_old_sub, l_old_locator, l_lpn_id, l_tran_lpn_id
              FROM apps.mtl_material_transactions_temp
             WHERE transaction_temp_id = P_ID AND organization_id = P_ORG_ID;

            WRITE_LOG (
                   'Before update Subinvenory code '
                || l_old_sub
                || ' locator ID '
                || l_old_locator
                || ' LPN ID '
                || l_lpn_id
                || ' Transfer LPN ID'
                || l_tran_lpn_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                WRITE_LOG (SQLERRM);
                WRITE_LOG (
                       ' No Transaction Temp records found for given id = '
                    || P_ID);
                RAISE g_invalid_excpn;
        END;

        --
        g_audit_rec.STATUS                  := 'INPROCESS';
        g_audit_rec.OLD_SUBINV_CODE         := l_old_sub;
        g_audit_rec.OLD_LOCATOR_ID          := l_old_locator;
        g_audit_rec.OLD_MMTT_TRANS_LPN_ID   := l_tran_lpn_id;
        g_audit_rec.OLD_MMTT_LPN_ID         := l_lpn_id;

        UPDATE apps.mtl_material_transactions_temp
           SET lock_flag = NULL, process_flag = 'Y', ERROR_CODE = NULL,
               error_explanation = NULL, SUBINVENTORY_CODE = NVL (P_SUBINV, SUBINVENTORY_CODE), LOCATOR_ID = NVL (P_LOC_ID, LOCATOR_ID),
               lpn_id = DECODE (P_IN_LPN, -1, NULL, NVL (P_IN_LPN, lpn_id)), TRANSFER_LPN_ID = DECODE (P_TRANSFER_LPN, -1, NULL, NVL (P_TRANSFER_LPN, TRANSFER_LPN_ID)), LAST_UPDATED_BY = FND_GLOBAL.user_id,
               LAST_UPDATE_DATE = SYSDATE
         WHERE transaction_temp_id = P_ID;

        SELECT SUBINVENTORY_CODE, LOCATOR_ID, LPN_ID,
               TRANSFER_LPN_ID
          INTO g_audit_rec.NEW_SUBINV_CODE, g_audit_rec.NEW_LOCATOR_ID, g_audit_rec.NEW_MMTT_LPN_ID, g_audit_rec.NEW_MMTT_TRANS_LPN_ID
          FROM apps.mtl_material_transactions_temp
         WHERE transaction_temp_id = P_ID;

        WRITE_LOG (
               'After update Subinvenory code '
            || g_audit_rec.NEW_SUBINV_CODE
            || ' locator ID '
            || g_audit_rec.NEW_LOCATOR_ID
            || ' LPN ID '
            || g_audit_rec.NEW_MMTT_LPN_ID
            || ' Transfer LPN ID'
            || g_audit_rec.NEW_MMTT_TRANS_LPN_ID);

        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN g_invalid_excpn
        THEN
            p_out_error_code   := 2;
            g_err_buf          :=
                ' No Transaction Temp records found for given id = ' || P_ID;
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.MMTT_UPDATE_FIX: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE g_invalid_excpn;
    END MMTT_UPDATE_FIX;

    /******************************************************************************/
    /* Name         : WDD_UPDATE_FIX
    /* Description  : Procedure to fix WSH_DELIVERY_DETAIL related records
    /******************************************************************************/
    PROCEDURE WDD_UPDATE_FIX (p_out_error_buff      OUT VARCHAR2,
                              p_out_error_code      OUT NUMBER,
                              P_ID               IN     NUMBER,
                              P_ORG_ID           IN     NUMBER,
                              P_SUBINV           IN     VARCHAR2,
                              P_LOC_ID           IN     NUMBER)
    IS
        l_old_sub       VARCHAR2 (30);
        l_old_locator   NUMBER;
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG (
            ' Start of Deckers DC Operations Support Fix - WSH_DELIVERY_DETAIL - UPDATE FIX');
        WRITE_LOG (' Parameters');
        WRITE_LOG (' Detail Delivery ID   =' || P_ID);
        WRITE_LOG (' Organization ID      =' || P_ORG_ID);
        WRITE_LOG (' Sub Inventory        =' || P_SUBINV);
        WRITE_LOG (' Locator ID           =' || P_LOC_ID);

        /* Inititalize variables*/
        p_out_error_code              := 0;
        p_out_error_buff              := NULL;
        g_audit_rec.ID_COLUMN         := 'DELIVERY_DETAIL_ID';

        /*End of initialization*/
        --
        BEGIN
            SELECT subinventory, locator_id
              INTO l_old_sub, l_old_locator
              FROM wsh_delivery_details
             WHERE delivery_detail_id = P_ID AND organization_id = P_ORG_ID;

            WRITE_LOG (
                   'Before update Subinvenory code '
                || l_old_sub
                || ' locator ID '
                || l_old_locator);
        EXCEPTION
            WHEN OTHERS
            THEN
                WRITE_LOG (SQLERRM);
                WRITE_LOG (
                    ' No Delivery records found for given id = ' || P_ID);
                RAISE g_invalid_excpn;
        END;

        --
        g_audit_rec.STATUS            := 'INPROCESS';
        g_audit_rec.OLD_SUBINV_CODE   := l_old_sub;
        g_audit_rec.OLD_LOCATOR_ID    := l_old_locator;

        UPDATE apps.wsh_delivery_details
           SET subinventory = NVL (P_SUBINV, subinventory), locator_id = NVL (P_LOC_ID, locator_id), LAST_UPDATED_BY = FND_GLOBAL.user_id,
               LAST_UPDATE_DATE = SYSDATE
         WHERE delivery_detail_id = P_ID;

        SELECT subinventory, locator_id
          INTO g_audit_rec.NEW_SUBINV_CODE, g_audit_rec.NEW_LOCATOR_ID
          FROM wsh_delivery_details
         WHERE delivery_detail_id = P_ID;

        WRITE_LOG (
               'After update Subinvenory code '
            || g_audit_rec.NEW_SUBINV_CODE
            || ' locator ID '
            || g_audit_rec.NEW_LOCATOR_ID);

        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN g_invalid_excpn
        THEN
            p_out_error_code   := 2;
            g_err_buf          :=
                ' No Delivery records found for given id = ' || P_ID;
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.WDD_UPDATE_FIX: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
    END WDD_UPDATE_FIX;

    /******************************************************************************/
    /* Name         : MTR_UPDATE_FIX
    /* Description  : Procedure to fix MTL_RESERVATIONS related records
    /******************************************************************************/
    PROCEDURE MTR_UPDATE_FIX (p_out_error_buff      OUT VARCHAR2,
                              p_out_error_code      OUT NUMBER,
                              P_ID               IN     NUMBER,
                              P_ORG_ID           IN     NUMBER,
                              P_SUBINV           IN     VARCHAR2,
                              P_LOC_ID           IN     NUMBER)
    IS
        l_old_sub       VARCHAR2 (30);
        l_old_locator   NUMBER;
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG (
            ' Start of Deckers DC Operations Support Fix - MTL_RESERVATIONS - UPDATE FIX');
        WRITE_LOG (' Parameters');
        WRITE_LOG (' Reservation ID     =' || P_ID);
        WRITE_LOG (' Organization ID    =' || P_ORG_ID);
        WRITE_LOG (' Sub Inventory Code =' || P_SUBINV);
        WRITE_LOG (' Locator ID         =' || P_LOC_ID);

        /* Inititalize variables*/
        p_out_error_code              := 0;
        p_out_error_buff              := NULL;
        g_audit_rec.ID_COLUMN         := 'RESERVATION_ID';

        /*End of initialization*/
        --
        --
        BEGIN
            SELECT subinventory_code, locator_id
              INTO l_old_sub, l_old_locator
              FROM mtl_reservations
             WHERE reservation_id = P_ID AND organization_id = P_ORG_ID;

            WRITE_LOG (
                   'Before update Subinvenory code '
                || l_old_sub
                || ' locator ID '
                || l_old_locator);
        EXCEPTION
            WHEN OTHERS
            THEN
                WRITE_LOG (SQLERRM);
                WRITE_LOG (' No reservation found for given id = ' || P_ID);
                RAISE g_invalid_excpn;
        END;

        --
        g_audit_rec.STATUS            := 'INPROCESS';
        g_audit_rec.OLD_SUBINV_CODE   := l_old_sub;
        g_audit_rec.OLD_LOCATOR_ID    := l_old_locator;

        /*Update Reservation table*/
        UPDATE apps.mtl_reservations
           SET subinventory_code = NVL (P_SUBINV, subinventory_code), locator_id = NVL (P_LOC_ID, locator_id), LAST_UPDATED_BY = FND_GLOBAL.user_id,
               LAST_UPDATE_DATE = SYSDATE
         WHERE reservation_id = P_ID;

        SELECT subinventory_code, locator_id
          INTO g_audit_rec.NEW_SUBINV_CODE, g_audit_rec.NEW_LOCATOR_ID
          FROM mtl_reservations
         WHERE reservation_id = P_ID;

        WRITE_LOG (
               'After update Subinvenory code '
            || g_audit_rec.NEW_SUBINV_CODE
            || ' locator ID '
            || g_audit_rec.NEW_LOCATOR_ID);

        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN g_invalid_excpn
        THEN
            p_out_error_code   := 2;
            g_err_buf          :=
                ' No reservation found for given id = ' || P_ID;
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.MTR_UPDATE_FIX: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
    END MTR_UPDATE_FIX;

    /******************************************************************************/
    /* Name         : MTRH_PYRAMID_PUSH
    /* Description  : Procedure to fix push wave into PYRAMID (US3)
    /******************************************************************************/
    PROCEDURE MTRH_PYRAMID_PUSH (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ID IN NUMBER
                                 , P_ORG_ID IN NUMBER)
    IS
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG (
            ' Start of Deckers DC Operations Support Fix - MTL_TXN_REQUEST_HEADERS - Push to Pyramid');
        WRITE_LOG (' Parameters');
        WRITE_LOG (' HEADER_ID     =' || P_ID);
        WRITE_LOG (' Organization ID    =' || P_ORG_ID);


        /* Inititalize variables*/
        p_out_error_code        := 0;
        p_out_error_buff        := NULL;
        g_audit_rec.ID_COLUMN   := 'HEADER_ID';
        g_audit_rec.STATUS      := 'INPROCESS';

        UPDATE MTL_TXN_REQUEST_HEADERS mtrh
           SET attribute1   = 'Pending'
         WHERE     1 = 1
               AND mtrh.attribute1 IS NULL
               AND mtrh.header_id = P_ID
               AND mtrh.organization_id = P_ORG_ID;

        WRITE_LOG ('After update MTL_TXN_REQUEST_HEADERS.ATTRIBUTE1');

        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.MTRH_PYRAMID_PUSH: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
    END MTRH_PYRAMID_PUSH;

    /******************************************************************************/
    /* Name         : RSH_3PL_ASN_RESENT
    /* Description  : Procedure to resent ASN to 3PL
    /******************************************************************************/
    PROCEDURE RSH_3PL_ASN_RESENT (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_ID IN NUMBER)
    IS
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG (
            ' Start of Deckers DC Operations Support Fix - RCV_SHIPMENT_HEADERS - reset ASN_STATUS');
        WRITE_LOG (' Parameters');
        WRITE_LOG (' HEADER_ID     =' || P_ID);



        /* Inititalize variables*/
        p_out_error_code        := 0;
        p_out_error_buff        := NULL;
        g_audit_rec.ID_COLUMN   := 'ASN_STATUS';
        g_audit_rec.STATUS      := 'INPROCESS';

        UPDATE apps.rcv_shipment_headers
           SET asn_status   = 'PENDING'
         WHERE shipment_header_id = P_ID;

        WRITE_LOG ('After update RCV_SHIPMENT_HEADERS.ASN_STATUS');

        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.RSH_3PL_ASN_RESENT: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
    END RSH_3PL_ASN_RESENT;

    /******************************************************************************/
    /* Name         : DELETE_DO_DEBUG
    /* Description  : Procedure to delete do_debug records
    /******************************************************************************/
    PROCEDURE DELETE_DO_DEBUG (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, P_LOOKBACK_DAYS IN NUMBER)
    IS
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG (
            ' Start of Deckers DC Operations Support Fix - DO_DEBUG - DELETE');
        WRITE_LOG (' Parameters');
        WRITE_LOG (' Lookback Days     =' || P_LOOKBACK_DAYS);

        /* Inititalize variables*/
        p_out_error_code        := 0;
        p_out_error_buff        := NULL;
        g_audit_rec.ID_COLUMN   := 'LOOKBACK DAYS';

        --
        g_audit_rec.STATUS      := 'INPROCESS';

        DELETE FROM custom.do_debug
              WHERE creation_date < SYSDATE - NVL (P_LOOKBACK_DAYS, 3);

        WRITE_LOG (
            'Total records deleted from DO_DEBUG table = ' || SQL%ROWCOUNT);
        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG (LPAD ('-', 78, '-'));
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            g_err_buf          := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.MTR_UPDATE_FIX: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('-', 78, '-'));
            RAISE;
    END DELETE_DO_DEBUG;

    /******************************************************************************/
    /* Name         : MAIN_PROC
    /* Description  : Procedure to start Fix
    /******************************************************************************/
    PROCEDURE MAIN_PROC (p_out_error_buff        OUT VARCHAR2,
                         p_out_error_code        OUT NUMBER,
                         P_INCIDENT           IN     VARCHAR2,
                         P_TABLE_NAME         IN     VARCHAR2,
                         P_HIDDEN_PARAM_1     IN     VARCHAR2,
                         P_SHIPMENT_ACTION    IN     VARCHAR2,
                         P_ID                 IN     NUMBER,
                         P_DELIVERY_ID        IN     NUMBER,
                         P_ORG_ID             IN     NUMBER,
                         P_SUBINV             IN     VARCHAR2,
                         P_LOC_ID             IN     NUMBER,
                         P_LPN_CONTEXT        IN     NUMBER,
                         P_IN_PARENT_LPN      IN     NUMBER,
                         P_IN_OUTERMOST_LPN   IN     NUMBER,
                         P_IN_LPN             IN     NUMBER,
                         P_TRANSFER_LPN       IN     NUMBER,
                         P_TRACKING_NUMBER    IN     VARCHAR2,
                         P_PRO_NUMBER         IN     VARCHAR2,
                         P_SCAC_CODE          IN     VARCHAR2,
                         P_LOAD_ID            IN     VARCHAR2,
                         P_WAYBILL            IN     VARCHAR2)
    IS
    BEGIN
        /*Start process*/
        WRITE_LOG (LPAD ('+', 78, '+'));
        WRITE_LOG ('Start of Deckers DC Operations Support Fix');
        WRITE_LOG (LPAD ('-', 78, '-'));
        WRITE_LOG ('Parameters');
        WRITE_LOG ('Incident Number  =' || P_INCIDENT);
        WRITE_LOG ('Table Name       =' || P_TABLE_NAME); --Lokkup value XXDO_DC_SUP_FIX_TABLES
        WRITE_LOG ('ID               =' || P_ID);
        WRITE_LOG ('Organization ID  =' || P_ORG_ID);
        WRITE_LOG ('Sub Inventory    =' || P_SUBINV);
        WRITE_LOG ('Locator ID       =' || P_LOC_ID);
        WRITE_LOG ('LPN Context      =' || P_LPN_CONTEXT);
        WRITE_LOG ('Parent LPN       =' || P_IN_PARENT_LPN);
        WRITE_LOG ('Outermost LPN    =' || P_IN_OUTERMOST_LPN);
        WRITE_LOG ('LPN              =' || P_IN_LPN);
        WRITE_LOG ('Transfer LPN     =' || P_TRANSFER_LPN);
        WRITE_LOG ('');

        /* Inititalize Error code and errbuff*/
        p_out_error_code                    := 0;
        p_out_error_buff                    := NULL;
        /*End of initialization*/
        /*Initialize audit table columns*/

        /*Initialize aduit columns which are available*/
        WRITE_LOG ('Initialize Audit table columns ');
        g_audit_rec.REQUEST_ID              := fnd_global.conc_request_id;
        g_audit_rec.INCIDENT_NUM            := P_INCIDENT;
        g_audit_rec.TABLE_NAME              := P_TABLE_NAME;
        g_audit_rec.ID_COLUMN               := 'ID';
        g_audit_rec.ID_COLUMN_VALUE         := P_ID;
        g_audit_rec.STATUS                  := 'NEW';
        g_audit_rec.NEW_SUBINV_CODE         := P_SUBINV;
        g_audit_rec.NEW_LOCATOR_ID          := P_LOC_ID;
        g_audit_rec.NEW_LPN_CONTEXT         := P_LPN_CONTEXT;
        g_audit_rec.NEW_PARENT_LPN_ID       := P_IN_PARENT_LPN;
        g_audit_rec.NEW_OUTER_LPN_ID        := P_IN_OUTERMOST_LPN;
        g_audit_rec.NEW_MMTT_LPN_ID         := P_IN_LPN;
        g_audit_rec.NEW_MMTT_TRANS_LPN_ID   := P_TRANSFER_LPN;
        g_audit_rec.CREATION_DATE           := SYSDATE;
        g_audit_rec.CREATED_BY              := fnd_global.user_id;
        g_audit_rec.LAST_UPDATE_DATE        := SYSDATE;
        g_audit_rec.LAST_UPDATED_BY         := fnd_global.user_id;
        g_audit_rec.LAST_UPDATE_LOGIN       := fnd_global.login_id;
        WRITE_LOG ('');

        /*Insert/Create record into audit table to keep track of run*/
        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG ('');
        WRITE_LOG ('Call update procedures');

        /*Call procedure based on table name choosen*/
        IF P_TABLE_NAME = 'WMS_LICENSE_PLATE_NUMBERS'
        THEN
            /*Call LPN_UPDATE_FIX procedure to update table WMS_LICENSE_PLATE_NUMBERS */
            LPN_UPDATE_FIX (p_out_error_buff     => p_out_error_buff,
                            p_out_error_code     => p_out_error_code,
                            P_ID                 => P_ID,
                            P_ORG_ID             => P_ORG_ID,
                            P_SUBINV             => P_SUBINV,
                            P_LOC_ID             => P_LOC_ID,
                            P_LPN_CONTEXT        => P_LPN_CONTEXT,
                            P_IN_PARENT_LPN      => P_IN_PARENT_LPN,
                            P_IN_OUTERMOST_LPN   => P_IN_OUTERMOST_LPN);
        ELSIF P_TABLE_NAME = 'MTL_RESERVATIONS'
        THEN
            /*Call MTR_UPDATE_FIX procedure to update table MTL_RESERVATIONS*/
            MTR_UPDATE_FIX (p_out_error_buff   => p_out_error_buff,
                            p_out_error_code   => p_out_error_code,
                            P_ID               => P_ID,
                            P_ORG_ID           => P_ORG_ID,
                            P_SUBINV           => P_SUBINV,
                            P_LOC_ID           => P_LOC_ID);
        ELSIF P_TABLE_NAME = 'WSH_DELIVERY_DETAILS'
        THEN
            /*Call WDD_UPDATE_FIX procedure to update table WSH_DELIVERY_DETAILS*/
            WDD_UPDATE_FIX (p_out_error_buff   => p_out_error_buff,
                            p_out_error_code   => p_out_error_code,
                            P_ID               => P_ID,
                            P_ORG_ID           => P_ORG_ID,
                            P_SUBINV           => P_SUBINV,
                            P_LOC_ID           => P_LOC_ID);
        ELSIF P_TABLE_NAME = 'MTL_MATERIAL_TRANSACTIONS_TEMP'
        THEN
            /*Call MMTT_UPDATE_FIX procedure to update table MTL_MATERIAL_TRANSACTIONS_TEMP*/
            MMTT_UPDATE_FIX (p_out_error_buff   => p_out_error_buff,
                             p_out_error_code   => p_out_error_code,
                             P_ID               => P_ID,
                             P_ORG_ID           => P_ORG_ID,
                             P_SUBINV           => P_SUBINV,
                             P_LOC_ID           => P_LOC_ID,
                             P_IN_LPN           => P_IN_LPN,
                             P_TRANSFER_LPN     => P_TRANSFER_LPN);
        ELSIF P_TABLE_NAME = 'MTL_ONHAND_QUANTITIES_DETAIL'
        THEN
            /*Call MOQD_UPDATE_FIX procedure to update table MTL_ONHAND_QUANTITIES_DETAIL*/
            MOQD_UPDATE_FIX (p_out_error_buff => p_out_error_buff, p_out_error_code => p_out_error_code, P_ID => P_ID, P_ORG_ID => P_ORG_ID, P_SUBINV => P_SUBINV, P_LOC_ID => P_LOC_ID
                             , P_IN_LPN => P_IN_LPN);
        ELSIF P_TABLE_NAME = 'MTL_TXN_REQUEST_HEADERS'
        THEN
            /*Call MTRH_PYRAMID_PUSH procedure to push wave to pyramid(US3)*/
            MTRH_PYRAMID_PUSH (p_out_error_buff => p_out_error_buff, p_out_error_code => p_out_error_code, P_ID => P_ID
                               , P_ORG_ID => P_ORG_ID);
        ELSIF P_TABLE_NAME = 'RCV_SHIPMENT_HEADERS'
        THEN
            /*Call RSH_3PL_ASN_RESENT procedure to  resent ASN to 3PL*/
            RSH_3PL_ASN_RESENT (p_out_error_buff   => p_out_error_buff,
                                p_out_error_code   => p_out_error_code,
                                P_ID               => P_ID);
        ELSIF P_TABLE_NAME = 'DO_EDI856_PICK_TICKETS'
        THEN
            /*Call DO_EDI856_PICK_TICKETS procedure to delete delivery from shipment*/
            DELETE_PICKTICKET (p_out_error_buff => p_out_error_buff, p_out_error_code => p_out_error_code, p_shipment_id => p_id
                               , p_delivery_id => p_delivery_id);
        ELSIF P_TABLE_NAME = 'WSH_NEW_DELIVERIES'
        THEN
            /*Call UPDATE_DELIVERY_INFO procedure to update delivery information*/
            UPDATE_DELIVERY_INFO (p_out_error_buff    => p_out_error_buff,
                                  p_out_error_code    => p_out_error_code,
                                  p_delivery_id       => p_id,
                                  p_tracking_number   => p_tracking_number,
                                  p_pro_number        => p_pro_number,
                                  p_scac_code         => p_scac_code,
                                  p_load_id           => p_load_id,
                                  p_waybill           => p_waybill);
        ELSIF P_TABLE_NAME = 'DO_DEBUG'
        THEN
            /*Call DELETE_DO_DEBUG procedure to delete records from table DO_DEBUG*/
            DELETE_DO_DEBUG (p_out_error_buff   => p_out_error_buff,
                             p_out_error_code   => p_out_error_code,
                             P_LOOKBACK_DAYS    => P_ID);
        END IF;

        g_audit_rec.STATUS                  := 'PROCESSED';
        g_audit_rec.COMMENTS                := 'Task completed Successfully';
        INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                      p_out_error_code   => p_out_error_code);
        WRITE_LOG ('End of Deckers DC Operations Support Fix');
        WRITE_LOG (LPAD ('+', 78, '+'));
    EXCEPTION
        WHEN g_invalid_excpn
        THEN
            g_audit_rec.STATUS     := 'ERROR';
            g_audit_rec.COMMENTS   := SUBSTRB (g_err_buf, 1, 300);
            INSERT_AUDIT (p_out_error_buff   => p_out_error_buff,
                          p_out_error_code   => p_out_error_code);
            p_out_error_code       := 2;
            WRITE_LOG (LPAD ('+', 78, '+'));
        WHEN OTHERS
        THEN
            p_out_error_code   := 2;
            p_out_error_buff   := SQLERRM;
            WRITE_LOG (
                   'Procedure - XXDO_DC_SUP_FIX.MAIN_PROC: Other Error -  '
                || SQLERRM);
            WRITE_LOG (LPAD ('+', 78, '+'));
    END MAIN_PROC;

    /******************************************************************************/
    /* Name         : INSERT_CYCLE_COUNT_ITEMS
    /* Description  : Procedure to insert new items to mtl_cycle_count_items
    /******************************************************************************/
    PROCEDURE INSERT_CYCLE_COUNT_ITEMS (p_out_error_buff   OUT VARCHAR2,
                                        p_out_error_code   OUT NUMBER)
    IS
    BEGIN
        INSERT INTO apps.mtl_cycle_count_items
            (SELECT mcch.cycle_count_header_id,
                    msib.inventory_item_id,
                    SYSDATE last_update_Date,
                    (SELECT user_id
                       FROM apps.fnd_user
                      WHERE user_name = 'WMS_BATCH') last_updated_by,
                    SYSDATE creation_Date,
                    (SELECT user_id
                       FROM apps.fnd_user
                      WHERE user_name = 'WMS_BATCH') created_by,
                    -1  last_update_login,
                    (SELECT MAX (abc_class_id)
                       FROM apps.mtl_abc_classes
                      WHERE     organization_id = msib.organization_id
                            AND NVL (disable_date, SYSDATE + 1) >
                                TRUNC (SYSDATE)) abc_class_id,
                    NULL item_last_schedule_Date,
                    NULL schedule_order,
                    NULL approval_tolerance_positive,
                    NULL approval_tolerance_negative,
                    2   control_group_flag,
                    -1  request_id,
                    401 program_application_id,
                    31935 program_id,
                    SYSDATE program_update_date,
                    NULL attribute_category,
                    NULL attribute1,
                    NULL attribute2,
                    NULL attribute3,
                    NULL attribute4,
                    NULL attribute5,
                    NULL attribute6,
                    NULL attribute7,
                    NULL attribute8,
                    NULL attribute9,
                    NULL attribute10,
                    NULL attribute11,
                    NULL attribute12,
                    NULL attribute13,
                    NULL attribute14,
                    NULL attribute15
               FROM apps.mtl_parameters mp, apps.mtl_system_items_b msib, apps.mtl_item_categories mic,
                    apps.mtl_categories mc, apps.mtl_cycle_count_headers mcch
              WHERE     mp.wms_enabled_flag = 'Y'
                    AND msib.organization_id = mp.organization_id
                    AND mic.organization_id = msib.organization_id
                    AND mic.inventory_item_id = msib.inventory_item_id
                    AND mic.category_set_id = 1
                    AND mc.category_id = mic.category_id
                    AND mcch.organization_id = msib.organization_id
                    AND UPPER (mcch.cycle_count_header_name) =
                        UPPER (mc.segment1)
                    AND NOT EXISTS
                            (SELECT NULL
                               FROM apps.mtl_cycle_count_items mcci
                              WHERE     mcci.cycle_count_header_id =
                                        mcch.cycle_count_header_id
                                    AND inventory_item_id =
                                        msib.inventory_item_id)
                    AND EXISTS
                            (SELECT NULL
                               FROM apps.mtl_onhand_quantities_Detail moqd
                              WHERE     moqd.organization_id =
                                        msib.organization_id
                                    AND moqd.inventory_item_id =
                                        msib.inventory_item_id));

        COMMIT;
    END INSERT_CYCLE_COUNT_ITEMS;

    /******************************************************************************/
    /* Name         : DELETE_PICKTICKET
    /* Description  : Procedure to delete Delivery from do_edi856_pick_tickets
    /******************************************************************************/
    PROCEDURE DELETE_PICKTICKET (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, p_shipment_id IN NUMBER
                                 , p_delivery_id IN NUMBER)
    IS
    BEGIN
        /* Inititalize variables*/
        p_out_error_code   := 0;
        p_out_error_buff   := NULL;

        DELETE FROM
            do_edi.do_edi856_pick_tickets
              WHERE     shipment_id = p_shipment_id
                    AND delivery_id = p_delivery_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            WRITE_LOG (
                   'Exception while deleting the pickticket from the shipment: '
                || SQLERRM);
            p_out_error_code   := 2;
    END DELETE_PICKTICKET;

    /******************************************************************************/
    /* Name         : UPDATE_DELIVERY_INFO
    /* Description  : Procedure to delete Delivery from do_edi856_pick_tickets
    /******************************************************************************/
    PROCEDURE UPDATE_DELIVERY_INFO (p_out_error_buff       OUT VARCHAR2,
                                    p_out_error_code       OUT NUMBER,
                                    P_DELIVERY_ID       IN     NUMBER,
                                    P_TRACKING_NUMBER   IN     VARCHAR2,
                                    P_PRO_NUMBER        IN     VARCHAR2,
                                    P_SCAC_CODE         IN     VARCHAR2,
                                    P_LOAD_ID           IN     VARCHAR2,
                                    P_WAYBILL           IN     VARCHAR2)
    IS
        ln_value          VARCHAR2 (100);
        lv_proceed_flag   VARCHAR2 (1);
    BEGIN
        lv_proceed_flag   := 'Y';

        IF p_tracking_number IS NOT NULL AND p_pro_number IS NOT NULL
        THEN
            WRITE_LOG (
                'Delivery cannot have both tracking number and pro number');
            p_out_error_code   := 2;
            lv_proceed_flag    := 'N';
        ELSIF p_tracking_number IS NOT NULL
        THEN
            ln_value   := p_tracking_number;

            UPDATE apps.wsh_delivery_details
               SET tracking_number   = p_tracking_number
             WHERE delivery_detail_id IN
                       (SELECT delivery_detail_id
                          FROM apps.wsh_delivery_assignments
                         WHERE delivery_id = p_delivery_id);

            COMMIT;
        ELSIF p_pro_number IS NOT NULL
        THEN
            ln_value   := p_pro_number;
        END IF;

        IF lv_proceed_flag = 'Y'
        THEN
            UPDATE apps.wsh_new_deliveries
               SET attribute1 = NVL (ln_value, attribute1), attribute2 = NVL (p_scac_code, attribute2), attribute15 = NVL (p_load_id, attribute15),
                   waybill = NVL (p_waybill, waybill)
             WHERE delivery_id = p_delivery_id;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            WRITE_LOG (
                   'Exception while deleting the pickticket from the shipment: '
                || SQLERRM);
            p_out_error_code   := 2;
    END UPDATE_DELIVERY_INFO;
END XXDO_DC_SUP_FIX;
/
