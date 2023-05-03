--
-- XXD_PICK_RELEASE_HEAD_ARCHIVE  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PICK_RELEASE_HEAD_ARCHIVE"
AS
    /**********************************************************************************************
      * Package         : APPS.XXD_PICK_RELEASE_HEAD_ARCHIVE
      * Author          : BT Technology Team
      * Created         : 09-SEP-2016
      * Program Name    :
      * Description     :
      *
      * Modification    :
      *-----------------------------------------------------------------------------------------------
      *     Date         Developer             Version     Description
      *-----------------------------------------------------------------------------------------------
      *     09-SEP-2016 BT Technology Team     V1.1       Development
      ************************************************************************************************/
    PROCEDURE MAIN_PROGRAM (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2);
END XXD_PICK_RELEASE_HEAD_ARCHIVE;
/
