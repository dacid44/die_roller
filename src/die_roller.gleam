import argv
import gleam/bytes_builder
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result.{try}
import gleam/string
import mist.{type Connection, type ResponseData}

import dice
import dice/parser as dice_parser

pub fn main() {
  case argv.load().arguments {
    [] -> run_server()
    args -> run_cli(args)
  }
}

type ErrorKind {
  RequestError
  ParseError(dice_parser.ParseError)
}

fn run_cli(args: List(String)) {
  {
    use expression <- try(
      args
      |> string.join(" ")
      |> dice_parser.parse_dice
      |> result.map_error(dice_parser.parse_error_message),
    )
    expression
    |> dice.roll_dice
    |> int.to_string
    |> Ok
  }
  |> result.unwrap_both
  |> io.println
}

fn run_server() -> Nil {
  let _selector = process.new_selector()

  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        [] -> serve_file("public/index.html", "text/html")
        ["main.js"] -> serve_file("public/main.js", "text/javascript")
        ["check-expression"] -> {
          let result = {
            use params <- try(
              request.get_query(req)
              |> result.replace_error(RequestError),
            )
            use expression <- try(
              list.key_find(params, "expression")
              |> result.replace_error(RequestError),
            )
            use _ <- try(
              dice_parser.parse_dice(expression)
              |> result.map_error(ParseError),
            )
            Ok(Nil)
          }
          case result {
            Ok(_) ->
              response.new(200)
              |> set_response_json(json.object([#("valid", json.bool(True))]))
            Error(RequestError) ->
              http_error(400, "missing or invalid expression parameter")
            Error(ParseError(error)) ->
              response.new(200)
              |> set_response_json(
                json.object([
                  #("valid", json.bool(False)),
                  #(
                    "message",
                    json.string(dice_parser.parse_error_message(error)),
                  ),
                ]),
              )
          }
        }
        ["roll-dice"] -> {
          let result = {
            use params <- try(
              request.get_query(req)
              |> result.replace_error(RequestError),
            )
            use input <- try(
              list.key_find(params, "expression")
              |> result.replace_error(RequestError),
            )
            use expression <- try(
              dice_parser.parse_dice(input)
              |> result.map_error(ParseError),
            )
            Ok(dice.roll_dice(expression))
          }
          case result {
            Ok(result) ->
              response.new(200)
              |> response.prepend_header("content-type", "application/json")
              |> response.set_body(
                result
                |> int.to_string
                |> bytes_builder.from_string
                |> mist.Bytes,
              )
            Error(RequestError) ->
              http_error(400, "missing or invalid expression parameter")
            Error(ParseError(error)) ->
              http_error(400, dice_parser.parse_error_message(error))
          }
        }
        _ -> http_error(404, "not found")
      }
    }
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http
  process.sleep_forever()
}

fn http_error(error_code: Int, message: String) -> Response(ResponseData) {
  response.new(error_code)
  |> set_response_json(json.object([#("error", json.string(message))]))
}

fn set_response_json(
  response: Response(a),
  data: json.Json,
) -> Response(ResponseData) {
  response
  |> response.prepend_header("content-type", "application/json")
  |> response.set_body(
    data
    |> json.to_string_builder
    |> bytes_builder.from_string_builder
    |> mist.Bytes,
  )
}

fn serve_file(path: String, content_type: String) -> Response(ResponseData) {
  mist.send_file(path, offset: 0, limit: None)
  |> result.map(fn(file) {
    response.new(200)
    |> response.prepend_header("content-type", content_type)
    |> response.set_body(file)
  })
  |> result.lazy_unwrap(fn() { http_error(500, "static file missing") })
}
