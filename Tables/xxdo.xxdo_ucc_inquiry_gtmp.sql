--
-- XXDO_UCC_INQUIRY_GTMP  (Table) 
--
CREATE GLOBAL TEMPORARY TABLE XXDO.XXDO_UCC_INQUIRY_GTMP
(
  QR_IN_TYPE              VARCHAR2(500 BYTE),
  QR_IN_VALUE             VARCHAR2(500 BYTE),
  RESULT_CODE             VARCHAR2(500 BYTE),
  STATUS_CODE             VARCHAR2(500 BYTE),
  CONTAINER_QR_CODE       VARCHAR2(500 BYTE),
  UCC                     VARCHAR2(500 BYTE),
  QUANTITY                VARCHAR2(500 BYTE),
  UNIT_TYPE_CODE          VARCHAR2(500 BYTE),
  TRANSACTION_IDENTIFIER  VARCHAR2(500 BYTE),
  CONTAINER_TYPE_CODE     VARCHAR2(500 BYTE),
  CUSTOMER_CODE           VARCHAR2(500 BYTE),
  LOCATION_CODE           VARCHAR2(500 BYTE),
  CONTAINER_ITEM_COL_SEQ  NUMBER,
  PRODUCT_CODE_VALUE      VARCHAR2(500 BYTE),
  UPC                     VARCHAR2(500 BYTE),
  QUALITY_CODE            VARCHAR2(500 BYTE),
  PACKAGE_CODE_VALUE      VARCHAR2(500 BYTE)
)
ON COMMIT DELETE ROWS
NOCACHE
/
