import gleam/int
import gleam/list
import gleam/string
import prng/random

pub type Term {
  Constant(value: Int)
  Die(count: Int, size: Int, sign: Sign)
}

pub type Sign {
  Positive
  Negative
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

pub fn negate_if(value: Int, condition: Bool) -> Int {
  case condition {
    True -> -value
    False -> value
  }
}

fn eval_term(term: Term) -> Int {
  case term {
    Constant(value) -> value
    Die(count, size, sign) -> {
      let rng = random.int(1, size)
      list.repeat(Nil, count)
      |> list.map(fn(_) { random.random_sample(rng) })
      |> int.sum
      |> negate_if(sign == Negative)
    }
  }
}

pub fn roll_dice(dice: List(Term)) -> Int {
  dice
  |> list.map(eval_term)
  |> int.sum
}
