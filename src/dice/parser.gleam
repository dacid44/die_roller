import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string

import dice.{type Sign, type Term, Negative, Positive, negate_if}

pub type ParseError {
  ParseError(position: Int, kind: ParseErrorKind)
}

pub fn parse_error_message(error: ParseError) -> String {
  "at position "
  <> int.to_string(error.position)
  <> ": "
  <> parse_error_kind_message(error.kind)
}

pub type ParseErrorKind {
  EndOfExpression
  NotADigit
  MissingOperator
  IncompleteTerm
  TrailingOperator
  UnclosedParen
  ExtraClosingParen
}

pub fn parse_error_kind_message(error_kind: ParseErrorKind) -> String {
  case error_kind {
    EndOfExpression -> "end of expression reached before it was expected"
    NotADigit -> "a character was expected to be a digit, but was not"
    MissingOperator -> "missing an operator between two terms"
    IncompleteTerm -> "incomplete term"
    TrailingOperator -> "unused trailing operator"
    UnclosedParen -> "unclosed parentheses"
    ExtraClosingParen -> "extra closing parentheses"
  }
}

type TermParseState {
  ParseStart
  ParseConstant(Int)
  ParseDie(Int, Option(Int))
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
  needs_closing_paren: Bool,
  state: TermParseState,
) -> Result(#(List(Term), Int), ParseError) {
  let #(head, tail) = split_term_head(input)
  case state, head {
    ParseStart, Ok(digit) ->
      consume_term(
        tail,
        position + 1,
        terms,
        sign,
        needs_closing_paren,
        ParseConstant(digit),
      )
    ParseStart, Error("") -> Error(ParseError(position, EndOfExpression))
    ParseStart, Error("d") ->
      consume_term(
        tail,
        position + 1,
        terms,
        sign,
        needs_closing_paren,
        ParseDie(1, None),
      )
    ParseStart, Error(_) -> Error(ParseError(position, NotADigit))

    ParseConstant(num), Ok(digit) ->
      consume_term(
        tail,
        position + 1,
        terms,
        sign,
        needs_closing_paren,
        ParseConstant(num * 10 + digit),
      )
    ParseConstant(num), Error("") ->
      consume_expression(
        input,
        position,
        [dice.Constant(num), ..terms],
        None,
        needs_closing_paren,
      )
    ParseConstant(num), Error("d") ->
      consume_term(
        tail,
        position + 1,
        terms,
        sign,
        needs_closing_paren,
        ParseDie(num, None),
      )
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
        needs_closing_paren,
      )

    ParseDie(count, value), Ok(digit) ->
      consume_term(
        tail,
        position + 1,
        terms,
        sign,
        needs_closing_paren,
        ParseDie(count, Some(option.unwrap(value, 0) * 10 + digit)),
      )
    ParseDie(_, None), Error("") -> Error(ParseError(position, EndOfExpression))
    ParseDie(_, None), Error(_) -> Error(ParseError(position, IncompleteTerm))
    ParseDie(count, Some(value)), Error(_) ->
      consume_expression(
        input,
        position,
        [dice.Die(count, value, sign), ..terms],
        None,
        needs_closing_paren,
      )
  }
}

fn consume_expression(
  input: String,
  position: Int,
  terms: List(Term),
  sign: Option(Sign),
  needs_closing_paren: Bool,
) -> Result(#(List(Term), Int), ParseError) {
  let #(head, tail) =
    input
    |> string.pop_grapheme
    |> result.unwrap(#("", ""))
  case sign, head {
    None, "" ->
      case needs_closing_paren {
        True -> Error(ParseError(position, UnclosedParen))
        False -> finish_terms(terms, position)
      }
    Some(_), "" -> Error(ParseError(position, TrailingOperator))

    _, " " ->
      consume_expression(tail, position + 1, terms, sign, needs_closing_paren)

    None, "+" | Some(Positive), "+" | Some(Negative), "-" ->
      consume_expression(
        tail,
        position + 1,
        terms,
        Some(Positive),
        needs_closing_paren,
      )
    None, "-" | Some(Positive), "-" | Some(Negative), "+" ->
      consume_expression(
        tail,
        position + 1,
        terms,
        Some(Negative),
        needs_closing_paren,
      )

    Some(sign), "(" -> {
      case consume_expression(tail, position + 1, [], Some(Positive), True) {
        Error(error) -> Error(error)
        Ok(#(subexpression, new_position)) ->
          consume_expression(
            string.drop_left(input, new_position - position),
            new_position,
            [dice.Parens(subexpression, sign), ..terms],
            None,
            needs_closing_paren,
          )
      }
    }
    Some(_), ")" -> Error(ParseError(position, TrailingOperator))
    None, ")" ->
      case needs_closing_paren {
        True -> finish_terms(terms, position + 1)
        False -> Error(ParseError(position, ExtraClosingParen))
      }

    Some(sign), _ ->
      consume_term(
        input,
        position,
        terms,
        sign,
        needs_closing_paren,
        ParseStart,
      )

    None, _ -> Error(ParseError(position, MissingOperator))
  }
}

fn finish_terms(
  terms: List(Term),
  position: Int,
) -> Result(#(List(Term), Int), ParseError) {
  #(
    terms
      |> list.reverse,
    position,
  )
  |> Ok
}

pub fn parse_dice(input: String) -> Result(List(Term), ParseError) {
  consume_expression(input, 0, [], Some(Positive), False)
  |> result.map(pair.first)
}
