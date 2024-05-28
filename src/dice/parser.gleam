import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/result
import gleam/int

import dice.{type Sign, type Term, Positive, Negative, negate_if}

pub type ParseError {
  ParseError(position: Int, kind: ParseErrorKind)
}

pub fn parse_error_message(error: ParseError) -> String {
  parse_error_kind_message(error.kind) <> " at position " <> int.to_string(error.position)
}

pub type ParseErrorKind {
  EndOfExpression
  NotADigit
  MissingOperator
}

pub fn parse_error_kind_message(error_kind: ParseErrorKind) -> String {
  case error_kind {
    EndOfExpression -> "end of expression reached before it was expected"
    NotADigit -> "a character was expected to be a digit, but was not"
    MissingOperator -> "missing an operator between two terms"
  }
}

type TermParseState {
  ParseStart
  ParseConstant(Int)
  ParseDie(Int, Int)
}

fn split_term_head(input: String) -> #(Result(Int, String), String) {
  case string.pop_grapheme(input) {
    Ok(#(head, tail)) -> #(
      head
        |> int.base_parse(10)
        |> result.replace_error(head),
      tail,
    )
    Error(_) -> #(Error(""), "")
  }
}

fn consume_term(
  input: String,
  position: Int,
  terms: List(Term),
  sign: Sign,
  state: TermParseState,
) -> Result(List(Term), ParseError) {
  let #(head, tail) = split_term_head(input)
  case state, head {
    ParseStart, Ok(digit) ->
      consume_term(tail, position + 1, terms, sign, ParseConstant(digit))
    ParseStart, Error("") -> Error(ParseError(position, EndOfExpression))
    ParseStart, Error("d") ->
      consume_term(tail, position + 1, terms, sign, ParseDie(1, 0))
    ParseStart, Error(_) -> Error(ParseError(position, NotADigit))

    ParseConstant(num), Ok(digit) ->
      consume_term(
        tail,
        position + 1,
        terms,
        sign,
        ParseConstant(num * 10 + digit),
      )
    ParseConstant(num), Error("") -> finish_terms([dice.Constant(num), ..terms])
    ParseConstant(num), Error("d") ->
      consume_term(tail, position + 1, terms, sign, ParseDie(num, 0))
    ParseConstant(num), Error(_) ->
      consume_expression(
        input,
        position,
        [
          num
            |> negate_if(sign == Negative)
            |> dice.Constant,
          ..terms
        ],
        None,
      )

    ParseDie(count, value), Ok(digit) ->
      consume_term(
        tail,
        position + 1,
        terms,
        sign,
        ParseDie(count, value * 10 + digit),
      )
    ParseDie(count, value), Error("") ->
      finish_terms([dice.Die(count, value, sign), ..terms])
    ParseDie(count, value), Error(_) ->
      consume_expression(
        input,
        position,
        [dice.Die(count, value, sign), ..terms],
        None,
      )
  }
}

fn consume_expression(
  input: String,
  position: Int,
  terms: List(Term),
  sign: Option(Sign),
) -> Result(List(Term), ParseError) {
  let #(head, tail) =
    input
    |> string.pop_grapheme
    |> result.unwrap(#("", ""))
  case sign, head {
    None, "" -> finish_terms(terms)
    Some(_), "" -> Error(ParseError(position, EndOfExpression))

    _, " " -> consume_expression(tail, position + 1, terms, sign)

    None, "+" | Some(Positive), "+" | Some(Negative), "-" ->
      consume_expression(tail, position + 1, terms, Some(Positive))
    None, "-" | Some(Positive), "-" | Some(Negative), "+" ->
      consume_expression(tail, position + 1, terms, Some(Negative))

    None, _ -> Error(ParseError(position, MissingOperator))
    Some(sign), _ -> consume_term(input, position, terms, sign, ParseStart)
  }
}

fn finish_terms(terms: List(Term)) -> Result(List(Term), ParseError) {
  terms
  |> list.reverse
  |> Ok
}

pub fn parse_dice(input: String) -> Result(List(Term), ParseError) {
  consume_expression(input, 0, [], Some(Positive))
}
