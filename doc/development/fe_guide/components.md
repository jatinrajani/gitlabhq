# Components

## Contents

- [Dropdowns](#dropdowns)

## Dropdowns

See also the [corresponding UX guide](https://design.gitlab.com/#/components/dropdowns).

### How to style a bootstrap dropdown

1. Use the HTML structure provided by the [docs][bootstrap-dropdowns]
1. Add a specific class to the top level `.dropdown` element

   ```Haml
   .dropdown.my-dropdown
     %button{ type: 'button', data: { toggle: 'dropdown' }, 'aria-haspopup': true, 'aria-expanded': false }
       %span.dropdown-toggle-text
         Toggle Dropdown
       = icon('chevron-down')

     %ul.dropdown-menu
       %li
         %a
           item!
   ```

   Or use the helpers

   ```Haml
   .dropdown.my-dropdown
     = dropdown_toggle('Toogle!', { toggle: 'dropdown' })
     = dropdown_content
       %li
         %a
           item!
   ```

[bootstrap-dropdowns]: https://getbootstrap.com/docs/3.3/javascript/#dropdowns
