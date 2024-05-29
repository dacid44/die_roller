module Api exposing (Validation, decodeValidation)

import Json.Decode as D


type alias Validation =
    { valid : Bool
    , message : Maybe String
    }


decodeValidation : D.Decoder Validation
decodeValidation =
    D.map2 Validation
        (D.field "valid" D.bool)
        (D.maybe (D.field "message" D.string))
