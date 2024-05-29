module Main exposing (main)

import Api
import Browser
import Html exposing (..)
import Http
import Maybe.Extra as Maybe
import Result.Extra as Result
import Theme
import Url.Builder as UrlBuilder
import W.Button as Button
import W.Container as Container
import W.Heading as Heading
import W.InputText as InputText
import W.Message as Message
import W.Styles
import W.Text as Text


type alias Model =
    { expression : String
    , expressionError : Maybe String
    , result : Maybe String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { expression = "", expressionError = Nothing, result = Nothing }, Cmd.none )


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
            [ Container.horizontal
            , Container.pad_4
            , Container.gap_3
            , Container.background Theme.baseBackground
            , Container.largeScreen
                []
            , Container.styleAttrs [ ( "height", "100%" ) ]
            ]
            [ Container.view
                [ Container.vertical
                , Container.pad_4
                , Container.gap_3
                ]
                ([ Heading.view [] [ text "Die Roller" ]
                 , Container.view [ Container.vertical ]
                    (InputText.view
                        [ InputText.placeholder "2d6 + 3"
                        , InputText.onEnter RollDice
                        , InputText.validation
                            (\_ ->
                                model.expressionError
                            )
                        , InputText.minLength 5
                        ]
                        { onInput = ExpressionChanged, value = model.expression }
                        :: (model.expressionError
                                |> Maybe.map (\message -> Message.view [ Message.danger ] [ Text.view [] [ text message ] ])
                                |> Maybe.toList
                           )
                    )
                 , Button.view [ Button.primary ] { label = [ text "Roll the dice!" ], onClick = RollDice }
                 ]
                    ++ (model.result |> Maybe.map (\result -> Text.view [] [ text result ]) |> Maybe.toList)
                )
            ]
        ]
    }


type Msg
    = ExpressionChanged String
    | ExpressionChecked (Result Http.Error Api.Validation)
    | RollDice
    | DiceRolled (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ExpressionChanged expression ->
            ( { model | expression = expression }
            , Http.get
                { url = UrlBuilder.relative [ "check-expression" ] [ UrlBuilder.string "expression" expression ]
                , expect = Http.expectJson ExpressionChecked Api.decodeValidation
                }
            )

        ExpressionChecked response ->
            ( { model
                | expressionError =
                    response
                        |> Result.map .message
                        |> Result.toMaybe
                        |> Maybe.join
              }
            , Cmd.none
            )

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
