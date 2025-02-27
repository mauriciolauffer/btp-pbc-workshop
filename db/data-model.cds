using {
      cuid,
      managed
} from '@sap/cds/common';

context ai.db {

      type KeyFact {
            fact     : String;
            category : String;
      }

      type Action {
            type          : String;
            value         : String;
            virtual descr : String
      }

      type BaseMail {
            subject            : String;
            body               : String;
            senderEmailAddress : String;
      }

      ... CREATE THE TABLES HERE ...
}
