use pulldown_cmark::{Parser, Event, Tag, TagEnd};
fn main() {
    let p = Parser::new("hello");
    for e in p {
        match e {
            Event::End(tag_end) => {
                match tag_end {
                    TagEnd::Paragraph => println!("p"),
                    _ => {}
                }
            }
            _ => {}
        }
    }
}
