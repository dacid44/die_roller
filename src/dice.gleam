import gleam/int
import gleam/list
import prng/random

pub type Term {
  Constant(value: Int)
  Die(count: Int, size: Int, sign: Sign)
}

pub type Sign {
  Positive
  Negative
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
