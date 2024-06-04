import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(task: Option(String), tasks: List(String))
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  #(Model(task: None, tasks: []), read_localstorage("task"))
}

// UPDATE ----------------------------------------------------------------------

pub opaque type Msg {
  UserUpdatedTask(String)
  UserAddedTask
  CacheUpdatedMessage(Result(String, Nil))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserUpdatedTask(input) -> #(
      Model(..model, task: Some(input)),
      write_localstorage("task", input),
    )
    CacheUpdatedMessage(Ok(task)) -> #(
      Model(..model, task: Some(task)),
      effect.none(),
    )
    CacheUpdatedMessage(Error(_)) -> #(model, effect.none())
    UserAddedTask -> {
      case model.task {
        Some(task) -> #(
          Model(task: None, tasks: list.concat([model.tasks, [task]])),
          effect.none(),
        )
        None -> #(model, effect.none())
      }
    }
  }
}

fn read_localstorage(key: String) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    do_read_localstorage(key)
    |> CacheUpdatedMessage
    |> dispatch
  })
}

@external(javascript, "./todo_mvc.ffi.mjs", "read_localstorage")
fn do_read_localstorage(_key: String) -> Result(String, Nil) {
  Error(Nil)
}

fn write_localstorage(key: String, value: String) -> Effect(msg) {
  effect.from(fn(_) { do_write_localstorage(key, value) })
}

@external(javascript, "./todo_mvc.ffi.mjs", "write_localstorage")
fn do_write_localstorage(_key: String, _value: String) -> Nil {
  Nil
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let task = option.unwrap(model.task, "")

  html.div(
    [attribute.class("mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 h-screen py-10")],
    [
      html.div([attribute.class("mx-auto max-w-3xl text-center")], [
        html.h2(
          [
            attribute.class(
              "text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl",
            ),
          ],
          [element.text("Gleam TODO App")],
        ),
        html.p([attribute.class("mt-6 text-lg leading-8 text-gray-600")], [
          element.text(
            "This is a simple TODO app written in Gleam using the Lustre framework.",
          ),
        ]),
        html.form([attribute.method("POST"), event.on_submit(UserAddedTask)], [
          input(
            "Task",
            "Enter your task here.",
            "todo",
            "text",
            task,
            UserUpdatedTask,
          ),
        ]),
        html.ul([], list_items(model.tasks)),
      ]),
    ],
  )
}

fn list_items(tasks: List(String)) -> List(Element(Msg)) {
  list.map(tasks, list_task)
}

fn list_task(task: String) -> Element(Msg) {
  html.li([], [element.text(task)])
}

fn input(
  label: String,
  placeholder: String,
  for: String,
  type_: String,
  value: String,
  msg: fn(String) -> Msg,
) -> Element(Msg) {
  html.div([attribute.class("relative")], [
    html.label(
      [
        attribute.attribute("for", for),
        attribute.class(
          "absolute -top-2 left-2 inline-block bg-white px-1 text-xs font-medium text-gray-900",
        ),
      ],
      [element.text(label)],
    ),
    html.input([
      attribute.type_(type_),
      attribute.name(for),
      attribute.id(for),
      attribute.class(
        "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
      ),
      attribute.placeholder(placeholder),
      attribute.value(value),
      event.on_input(msg),
    ]),
  ])
}
