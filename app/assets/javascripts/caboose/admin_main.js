
function curr(x)
{
  if (!x) return '0.00'
  var t = typeof x;
  if (t == 'boolean') return '0.00';
  if (t == 'number')  return x.toFixed(2);
  if (t == 'string')  return parseFloat(x).toFixed(2);
  console.log("curr doesn't know what this is:");
  console.log(x);
  console.log(t);
  return 'STAHP'
}

function add_to_crumbtrail(href, text)
{
  var c = $('#crumbtrail');
  if (!c.is(':empty'))
    c.append(' > ');
  c.append($('<a/>').attr('href', href).html(text));
}
