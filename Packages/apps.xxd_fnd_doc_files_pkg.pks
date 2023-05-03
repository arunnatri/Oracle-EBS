--
-- XXD_FND_DOC_FILES_PKG  (Package) 
--
--  Dependencies: 
--   FND_ATTACHED_DOCUMENTS (Synonym)
--   DBA_DIRECTORIES (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FND_DOC_FILES_PKG"
AS
    /************************************************************************************************
       * Package         : XXD_FND_DOC_FILES_PKG
       * Description     : Generic Package to Upload FND Document Files by Entities
    *                 : AP_INVOICES\OE_ORDER_HEADERS\REQ_HEADERS\PO_HEADER\AR_CUSTOMERS\GL_JE_HEADERS
       * Notes           :
       * Modification    :
       *-----------------------------------------------------------------------------------------------
       * Date         Version#      Name                       Description
       *-----------------------------------------------------------------------------------------------
       * 04-APR-2018  1.0           Aravind Kannuri           Initial Version for CCR0007106
    * 30-JUL-2018  1.1           Aravind Kannuri    Added Parameter for CCR0007350
       ************************************************************************************************/

    --Upload FND Document files by Entity
    FUNCTION get_doc_files (p_pk1_value_id IN NUMBER, p_entity_name IN fnd_attached_documents.entity_name%TYPE, --Added new parameter as per version 1.1
                                                                                                                p_directory_name IN dba_directories.directory_name%TYPE DEFAULT NULL
                            , p_file_prefix IN VARCHAR2)
        RETURN VARCHAR2;
END xxd_fnd_doc_files_pkg;
/
