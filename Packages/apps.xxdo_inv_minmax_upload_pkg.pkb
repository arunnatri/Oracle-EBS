--
-- XXDO_INV_MINMAX_UPLOAD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INV_MINMAX_UPLOAD_PKG"
AS
    /*******************************************************************************
       * Program Name : xxdo_inv_minmax_upload_pkg
       * Language     : PL/SQL
       * Description  : This package is used to upload min max planning details for items
       *
       * History      :
       *
       * WHO            WHAT              Desc                             WHEN
       * -------------- ---------------------------------------------- ---------------
       * Bala Murugesan  1.0             Initial Version                Mar/13/2017
       * --------------------------------------------------------------------------- */


    L_PACKAGE_NAME   CONSTANT VARCHAR2 (40) := 'XXDO_INV_MINMAX_UPLOAD_PKG.';



    PROCEDURE minmax_update (p_org_id          IN NUMBER,
                             p_subinventory    IN VARCHAR2,
                             p_item_id         IN NUMBER,
                             p_min_qty         IN NUMBER,
                             p_max_qty         IN NUMBER,
                             p_ord_cpq         IN NUMBER,
                             p_source_org_id   IN NUMBER,
                             p_lead_time       IN NUMBER)
    IS
        l_org_id                         VARCHAR2 (10);
        l_subinventory                   VARCHAR2 (10);
        l_min_qty                        NUMBER;
        l_max_qty                        NUMBER;
        l_min_qty_old                    NUMBER;
        l_max_qty_old                    NUMBER;
        l_ord_cpq                        NUMBER;
        l_ord_Min                        NUMBER;
        l_ord_cpq_old                    NUMBER;
        l_ord_Min_old                    NUMBER;
        l_ord_cpq_sug                    NUMBER;
        l_ord_cpq_sug1                   NUMBER;
        l_ord_Min_sug                    NUMBER;
        l_ord_Min_sug1                   NUMBER;
        l_LAST_UPDATED_BY                NUMBER := FND_GLOBAL.USER_ID;
        l_CREATED_BY                     NUMBER := FND_GLOBAL.USER_ID;
        l_LAST_UPDATE_LOGIN              NUMBER := FND_GLOBAL.LOGIN_ID;

        l_Item_exists                    VARCHAR2 (3);
        l_locator_exists                 VARCHAR2 (3);
        l_cnt                            NUMBER;
        l_cpq                            NUMBER;
        l_mod                            NUMBER;
        l_chr_return_status              VARCHAR2 (30);
        l_chr_error_message              VARCHAR2 (2000);
        --l_status             varchar2(3);
        l_item_id                        NUMBER := NULL;
        l_status_code                    VARCHAR2 (60) := NULL;
        l_source_org_item_id             NUMBER := NULL;
        l_src_org_status_code            VARCHAR2 (60) := NULL;
        l_postprocessing_lead_time       NUMBER;
        l_preprocessing_lead_time        NUMBER;
        l_processing_lead_time           NUMBER;
        l_postprocessing_lead_time_old   NUMBER;
        l_preprocessing_lead_time_old    NUMBER;
        l_processing_lead_time_old       NUMBER;
        l_source_org_id                  NUMBER;
        l_org_code                       VARCHAR2 (10);
        l_src_ord_cpq                    NUMBER;

        l_minmax_rowid                   ROWID;
        le_webadi_exception              EXCEPTION;
    --Invalid_SKU EXCEPTION;
    --PRAGMA EXCEPTION_INIT(Invalid_SKU, -00054);

    BEGIN
        l_chr_return_status   := G_RET_SUCCESS;
        l_chr_error_message   := NULL;


        IF p_org_id = p_source_org_id
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                   l_chr_error_message
                || 'Min Max Org and Source Org can not be same';
        END IF;

        BEGIN
            SELECT ORGANIZATION_ID, organization_code
              INTO l_org_id, l_org_code
              FROM apps.mtl_parameters mp1
             WHERE organization_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_org_id     := NULL;
                l_org_code   := NULL;
        END;

        IF l_org_id IS NULL
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Min Max Org is not valid';
        END IF;

        BEGIN
            SELECT SECONDARY_INVENTORY_NAME
              INTO l_subinventory
              FROM mtl_secondary_inventories
             WHERE     organization_id = p_org_id
                   AND SECONDARY_INVENTORY_NAME = p_subinventory;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_subinventory   := NULL;
        END;

        IF l_subinventory IS NULL
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                   l_chr_error_message
                || ',Min Max Org and subinventory combination is not valid';
        END IF;

        BEGIN
            SELECT inventory_item_id, inventory_item_status_code
              INTO l_item_id, l_status_code
              FROM apps.mtl_system_items_b msi
             WHERE     msi.organization_id = p_org_id
                   AND msi.inventory_item_id = p_item_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_item_id       := NULL;
                l_status_code   := NULL;
        END;

        IF l_item_id IS NULL
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Item is not assigned to Min Max Org';
        END IF;

        IF l_status_code = 'Inactive'
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Item is Inactive in Min Max Org';
        END IF;

        IF l_status_code = 'Planned'
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                   l_chr_error_message
                || ',Item is in Planned status in Min Max Org';
        END IF;

        BEGIN
            SELECT inventory_item_id, inventory_item_status_code, fixed_lot_multiplier
              INTO l_source_org_item_id, l_src_org_status_code, l_src_ord_cpq
              FROM apps.mtl_system_items_b msi
             WHERE     msi.organization_id = p_source_org_id
                   AND msi.inventory_item_id = p_item_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_source_org_item_id    := NULL;
                l_src_org_status_code   := NULL;
                l_src_ord_cpq           := NULL;
        END;

        IF l_source_org_item_id IS NULL
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Item is not assigned to Source Org';
        END IF;

        IF l_src_org_status_code = 'Inactive'
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Item is Inactive in Source Org';
        END IF;

        IF l_src_org_status_code = 'Planned'
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                   l_chr_error_message
                || ',Item is in Planned status in Source Org';
        END IF;

        IF p_min_qty IS NULL
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Minimum Qty can not be blank';
        END IF;


        IF p_min_qty < 0
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Minimum Qty can not be negative';
        END IF;

        IF p_min_qty = 0
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Minimum Qty can not be zero';
        END IF;

        IF p_min_qty <> TRUNC (p_min_qty)
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Minimum Qty should be whole number';
        END IF;


        IF p_max_qty IS NULL
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Maximum Qty can not be blank';
        END IF;


        IF p_max_qty < 0
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Maximum Qty can not be negative';
        END IF;

        IF p_max_qty = 0
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Maximum Qty can not be zero';
        END IF;

        IF p_max_qty <> TRUNC (p_max_qty)
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Maximum Qty should be whole number';
        END IF;

        IF p_min_qty >= p_max_qty
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                   l_chr_error_message
                || ',Minimum Qty should be greater than  Maximum Qty';
        END IF;

        BEGIN
            SELECT ORGANIZATION_ID
              INTO l_source_org_id
              FROM apps.mtl_parameters mp1
             WHERE organization_id = p_source_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_source_org_id   := NULL;
        END;

        IF l_source_org_id IS NULL
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                l_chr_error_message || ',Source From Org is not valid';
        END IF;

        IF p_ord_cpq < 0
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                   l_chr_error_message
                || ',Fixed Lot Multiplier can not be negative';
        END IF;

        IF p_ord_cpq <> TRUNC (p_ord_cpq)
        THEN
            l_chr_return_status   := G_RET_ERROR;
            l_chr_error_message   :=
                   l_chr_error_message
                || ',Fixed Lot Multiplier should be whole number';
        END IF;

        -- If case pack qty is not passed, take it from source org
        IF NVL (p_ord_cpq, 0) <> 0
        THEN
            l_src_ord_cpq   := p_ord_cpq;
        END IF;

        IF p_lead_time IS NOT NULL
        THEN
            IF p_lead_time < 0
            THEN
                l_chr_return_status   := G_RET_ERROR;
                l_chr_error_message   :=
                    l_chr_error_message || ',Lead Time can not be negative';
            END IF;


            IF p_lead_time <> TRUNC (p_lead_time)
            THEN
                l_chr_return_status   := G_RET_ERROR;
                l_chr_error_message   :=
                       l_chr_error_message
                    || ',Lead Time should be whole number';
            END IF;
        END IF;


        IF l_chr_error_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        END IF;

        BEGIN
            SELECT description, tag
              INTO l_preprocessing_lead_time, l_postprocessing_lead_time
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_ORG_PRE_POST_LEAD_TIME'
                   AND view_application_id = 700
                   AND lookup_code = l_org_code
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                l_preprocessing_lead_time    := 1;
                l_postprocessing_lead_time   := 1;
        END;

        IF p_lead_time IS NOT NULL
        THEN
            --            l_preprocessing_lead_time := 0;
            l_processing_lead_time   := p_lead_time;
        --            l_postprocessing_lead_time := 0;
        ELSE
            --            l_preprocessing_lead_time := 0;
            l_processing_lead_time   := 0;
        --            l_postprocessing_lead_time := 0;
        END IF;



        BEGIN
            SELECT 'YES', MIN_MINMAX_QUANTITY, MAX_MINMAX_QUANTITY,
                   preprocessing_lead_time, processing_lead_time, postprocessing_lead_time,
                   FIXED_LOT_MULTIPLE, ROWID
              INTO l_Item_exists, l_min_qty_old, l_max_qty_old, l_preprocessing_lead_time_old,
                                l_processing_lead_time_old, l_postprocessing_lead_time_old, l_ord_cpq,
                                l_minmax_rowid
              FROM MTL_ITEM_SUB_INVENTORIES
             WHERE     SECONDARY_INVENTORY = p_subinventory
                   AND organization_id = p_org_id
                   AND INVENTORY_ITEM_ID = p_Item_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_Item_exists   := 'NO';
            WHEN OTHERS
            THEN
                l_Item_exists   := 'NO';
        END;

        IF l_Item_exists = 'NO'      -- Item does not exists insert new record
        THEN
            INSERT /*+ APPEND */
                   INTO MTL_ITEM_SUB_INVENTORIES (INVENTORY_ITEM_ID,
                                                  ORGANIZATION_ID,
                                                  SECONDARY_INVENTORY,
                                                  MIN_MINMAX_QUANTITY,
                                                  MAX_MINMAX_QUANTITY,
                                                  INVENTORY_PLANNING_CODE, -- 2 Min-Max
                                                  SOURCE_TYPE,
                                                  SOURCE_ORGANIZATION_ID,
                                                  LAST_UPDATE_DATE,
                                                  LAST_UPDATED_BY,
                                                  CREATION_DATE,
                                                  CREATED_BY,
                                                  LAST_UPDATE_LOGIN,
                                                  preprocessing_lead_time,
                                                  processing_lead_time,
                                                  postprocessing_lead_time,
                                                  fixed_lot_multiple)
                 VALUES (p_Item_id, p_org_id, p_subinventory,
                         p_min_qty, p_max_qty, 2,
                         1                                         --Inventory
                          , p_source_org_id, SYSDATE,
                         l_LAST_UPDATED_BY, SYSDATE, l_CREATED_BY,
                         l_LAST_UPDATE_LOGIN, l_preprocessing_lead_time, l_processing_lead_time
                         , l_postprocessing_lead_time, l_src_ord_cpq);

            INSERT /*+ APPEND */
                   INTO XXDO_INV_MINMAX_UPLOAD_LOG (
                            change_seq_id,
                            organization_id,
                            subinventory_name,
                            source_org_id,
                            inventory_item_id,
                            min_quantity,
                            max_quantity,
                            lead_time,
                            preprocessing_lead_time,
                            processing_lead_time,
                            postprocessing_lead_time,
                            fixed_lot_multiplier,
                            old_min_quantity,
                            old_max_quantity,
                            old_preprocessing_lead_time,
                            old_processing_lead_time,
                            old_postprocessing_lead_time,
                            old_fixed_lot_multiplier,
                            created_by,
                            creation_date,
                            last_updated_by,
                            last_update_date,
                            last_update_login)
                 VALUES (xxdo_inv_minmax_upload_s.NEXTVAL, p_org_id, p_subinventory, p_source_org_id, p_item_id, p_min_qty, p_max_qty, p_lead_time, l_preprocessing_lead_time, l_processing_lead_time, l_postprocessing_lead_time, l_src_ord_cpq, l_min_qty_old, l_max_qty_old, l_preprocessing_lead_time_old, l_processing_lead_time_old, l_postprocessing_lead_time_old, l_ord_cpq, G_USER_ID, SYSDATE, G_USER_ID
                         , SYSDATE, G_LOGIN_ID);


            l_chr_return_status   := G_RET_SUCCESS;
            l_chr_error_message   := NULL;
        ELSE                        -- Item exists, update the existing record
            IF (NVL (l_min_qty_old, 0) <> NVL (p_min_qty, 0) OR NVL (l_max_qty_old, 0) <> NVL (p_max_qty, 0) OR NVL (l_preprocessing_lead_time_old, 0) <> NVL (l_preprocessing_lead_time, 0) OR NVL (l_processing_lead_time_old, 0) <> NVL (l_processing_lead_time, 0) OR NVL (l_postprocessing_lead_time_old, 0) <> NVL (l_postprocessing_lead_time, 0) OR NVL (l_src_ord_cpq, 0) <> NVL (l_ord_cpq, 0))
            THEN
                UPDATE MTL_ITEM_SUB_INVENTORIES
                   SET MIN_MINMAX_QUANTITY = p_min_qty, MAX_MINMAX_QUANTITY = p_max_qty, LAST_UPDATE_DATE = SYSDATE,
                       LAST_UPDATED_BY = l_LAST_UPDATED_BY, preprocessing_lead_time = l_preprocessing_lead_time, processing_lead_time = l_processing_lead_time,
                       postprocessing_lead_time = l_postprocessing_lead_time, fixed_lot_multiple = l_src_ord_cpq
                 WHERE /*    SECONDARY_INVENTORY = p_subinventory
                       AND organization_id = p_org_id
                       AND INVENTORY_ITEM_ID = p_Item_id;
                       */
                       ROWID = l_minmax_rowid;

                INSERT /*+ APPEND */
                       INTO XXDO_INV_MINMAX_UPLOAD_LOG (
                                change_seq_id,
                                organization_id,
                                subinventory_name,
                                source_org_id,
                                inventory_item_id,
                                min_quantity,
                                max_quantity,
                                lead_time,
                                preprocessing_lead_time,
                                processing_lead_time,
                                postprocessing_lead_time,
                                fixed_lot_multiplier,
                                old_min_quantity,
                                old_max_quantity,
                                old_preprocessing_lead_time,
                                old_processing_lead_time,
                                old_postprocessing_lead_time,
                                old_fixed_lot_multiplier,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                last_update_login)
                     VALUES (xxdo_inv_minmax_upload_s.NEXTVAL, p_org_id, p_subinventory, p_source_org_id, p_item_id, p_min_qty, p_max_qty, p_lead_time, l_preprocessing_lead_time, l_processing_lead_time, l_postprocessing_lead_time, l_src_ord_cpq, l_min_qty_old, l_max_qty_old, l_preprocessing_lead_time_old, l_processing_lead_time_old, l_postprocessing_lead_time_old, l_ord_cpq, G_USER_ID, SYSDATE, G_USER_ID
                             , SYSDATE, G_LOGIN_ID);


                l_chr_return_status   := G_RET_SUCCESS;
                l_chr_error_message   := NULL;
            ELSE
                l_chr_return_status   := G_RET_SUCCESS;
                l_chr_error_message   := NULL;
            END IF;
        END IF;
    --      COMMIT;

    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXDO_MIN_MAX_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_chr_error_message);
            l_chr_error_message   := fnd_message.get ();
            raise_application_error (-20000, l_chr_error_message);
        WHEN OTHERS
        THEN
            l_chr_error_message   := SQLERRM;
            raise_application_error (-20001, l_chr_error_message);
    END minmax_update;
END xxdo_inv_minmax_upload_pkg;
/
