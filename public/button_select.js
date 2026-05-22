// Transform a select field into a Bootstrap button group.
// The original select stays in the DOM (hidden) and remains the source of truth.
function styleSelectAsButtonGroup(fieldName, vertical) {
  var select = $('#batch_connect_session_context_' + fieldName);
  if (!select.length) return;

  // If already transformed, do nothing.
  if (select.data('buttonized')) return;
  select.data('buttonized', true);

  var container = select.parent();
  var groupClass = vertical ? 'btn-group-vertical w-100' : 'btn-group';
  var wrapper = $('<div class="mt-2" data-buttonized-field="' + fieldName + '"></div>');
  var btnGroup = $('<div class="' + groupClass + '" role="group"></div>');

  select.find('option').each(function () {
    var option = $(this);
    var value = option.attr('value');

    if (typeof value === 'undefined') return;

    var button = $('<button type="button" class="btn btn-outline-secondary"></button>');
    button.text(option.text());
    button.attr('data-option-value', value);

    if (vertical) {
      button.addClass('text-start');
    }

    if (select.val() === value) {
      button.addClass('active');
    }

    button.on('click', function () {
      if (select.val() !== value) {
        select.val(value).trigger('change');
      } else {
        // Ensure upstream handlers still run when clicking the active option.
        select.trigger('change');
      }
    });

    btnGroup.append(button);
  });

  var syncActiveState = function () {
    var selectedValue = String(select.val());
    btnGroup.find('.btn').removeClass('active');
    btnGroup.find('[data-option-value="' + selectedValue + '"]').addClass('active');
  };

  select.on('change', syncActiveState);
  syncActiveState();

  select.addClass('d-none').attr('aria-hidden', 'true');
  wrapper.append(btnGroup);
  select.after(wrapper);
}

function triggerSelectChange(fieldName) {
  var select = $('#batch_connect_session_context_' + fieldName);
  if (!select.length) return;
  select.trigger('change');
}

function syncFormDependentVisibility() {
  // Re-apply hide/show behavior from the currently selected options.
  triggerSelectChange('resources');
  triggerSelectChange('partitions');
}

$(document).ready(function () {
  styleSelectAsButtonGroup('gpu_model_interactive', false);
  styleSelectAsButtonGroup('gpu_model_other', false);
  styleSelectAsButtonGroup('gpu_model_custom', false);
  styleSelectAsButtonGroup('resources', true);
  styleSelectAsButtonGroup('interface', false);
  styleSelectAsButtonGroup('python', true);
  styleSelectAsButtonGroup('cuda_version', true);
  styleSelectAsButtonGroup('num_hours', true);

  syncFormDependentVisibility();

  // Safari can restore form values after ready; run one more pass.
  setTimeout(syncFormDependentVisibility, 0);
});

$(window).on('pageshow', syncFormDependentVisibility);
