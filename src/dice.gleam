import gleam/int
import gleam/list
import gleam/result.{try}
import gleam/string
import prng/random

pub type Term {
  Constant(value: Int)
  Die(count: Int, size: Int, is_negative: Bool)
}

fn parse_term(term: String) -> Result(Term, Nil) {
  use #(term, is_negative) <- try(case term {
    "+" <> term -> Ok(#(term, False))
    "-" <> term -> Ok(#(term, True))
    _ -> Error(Nil)
  })
  case string.split(term, "d") {
    [value] ->
      value
      |> int.parse
      |> result.map(fn(x) { Constant(negate_if(x, is_negative)) })
    ["", size] ->
      size
      |> int.parse
      |> result.map(fn(size) { Die(1, size, is_negative) })
    [count, size] -> {
      use count <- try(int.parse(count))
      use size <- try(int.parse(size))
      Ok(Die(count, size, is_negative))
    }
    _ -> Error(Nil)
  }
}

fn negate_if(value: Int, condition: Bool) -> Int {
  case condition {
    True -> -value
    False -> value
  }
}

pub fn parse_expression(expression: String) -> Result(List(Term), Nil) {
  expression
  |> string.split(" ")
  |> list.filter(fn(x) { x != "" })
  |> combine_operators([])
  |> list.map(parse_term)
  |> result.all
}

fn combine_operators(tokens: List(String), head: List(String)) -> List(String) {
  case tokens {
    [] -> list.reverse(head)
    ["+", token, ..rest] ->
      combine_operators(rest, [string.append("+", token), ..head])
    ["-", token, ..rest] ->
      combine_operators(rest, [string.append("-", token), ..head])
    ["+" <> _ as token, ..rest] | ["-" <> _ as token, ..rest] ->
      combine_operators(rest, [token, ..head])
    [token, ..rest] ->
      combine_operators(rest, [string.append("+", token), ..head])
  }
}

fn eval_term(term: Term) -> Int {
  case term {
    Constant(value) -> value
    Die(count, size, is_negative) -> {
      let rng = random.int(1, size)
      list.repeat(Nil, count)
      |> list.map(fn(_) { random.random_sample(rng) })
      |> int.sum
      |> negate_if(is_negative)
    }
  }
}

pub fn eval_expression(expression: List(Term)) -> Int {
  expression
  |> list.map(eval_term)
  |> int.sum
}

pub fn roll_dice(expression: String) -> Result(Int, Nil) {
  use expression <- try(parse_expression(expression))
  Ok(eval_expression(expression))
}
