module Main exposing (main)

import Browser
import Html exposing (..)
import Http
import Result.Extra as Result
import Theme
import Url.Builder as UrlBuilder
import W.Button as Button
import W.Container as Container
import W.Heading as Heading
import W.InputText as InputText
import W.Styles
import W.Text as Text


type alias Model =
    { expression : String
    , expressionIsValid : Bool
    , result : Maybe String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { expression = "", expressionIsValid = True, result = Nothing }, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    { title = "Die Roller"
    , body =
        [ W.Styles.globalStyles
        , Theme.globalProviderWithDarkMode
            { light = Theme.lightTheme
            , dark = Theme.darkTheme
            , strategy = Theme.systemStrategy
            }
        , Container.view
            [ Container.vertical
            , Container.pad_4
            , Container.gap_3
            , Container.background Theme.baseBackground
            , Container.styleAttrs [ ( "height", "100%" ) ]
            ]
            ([ Heading.view [] [ text "Die Roller" ]
             , InputText.view
                [ InputText.placeholder "2d6 + 3"
                , InputText.onEnter RollDice
                , InputText.validation
                    (\input ->
                        if Debug.log "test" model.expressionIsValid then
                            Just input

                        else
                            Nothing
                    )
                ]
                { onInput = ExpressionChanged, value = model.expression }
             , Button.view [ Button.primary ] { label = [ text "Roll the dice!" ], onClick = RollDice }
             ]
                ++ (model.result |> Maybe.map (\result -> [ Text.view [] [ text result ] ]) |> Maybe.withDefault [])
            )
        ]
    }


type Msg
    = ExpressionChanged String
    | ExpressionChecked (Result Http.Error ())
    | RollDice
    | DiceRolled (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ExpressionChanged expression ->
            ( { model | expression = expression }
            , Http.get
                { url = UrlBuilder.relative [ "check-expression" ] [ UrlBuilder.string "expression" expression ]
                , expect = Http.expectWhatever ExpressionChecked
                }
            )

        ExpressionChecked response ->
            ( { model | expressionIsValid = Result.isOk response, result = Just "asdf" }, Cmd.none )

        RollDice ->
            ( model
            , Http.get
                { url = UrlBuilder.relative [ "roll-dice" ] [ UrlBuilder.string "expression" model.expression ]
                , expect = Http.expectString DiceRolled
                }
            )

        DiceRolled (Ok response) ->
            ( { model | result = Just response }, Cmd.none )

        _ ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
